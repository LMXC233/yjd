#!/bin/bash
# T1 自愈流水线引导 v2：GitHub 间歇可达，只在好窗口发起构建；仓库极小，好窗口 30-60s 即可完成两次 fetch
J=/var/jenkins_home/jobs/yjd-ci
LOG=$J/builds/1/log

# 温和的 fast-fail：90 秒内低于 200 B/s 才断（只杀真死连接，容忍慢速）
docker exec -u root jenkins git config --system http.lowSpeedLimit 200 2>/dev/null
docker exec -u root jenkins git config --system http.lowSpeedTime 90 2>/dev/null

for cycle in $(seq 1 15); do
  NOW=$(date +%s)
  # 若有卡死构建（日志 3 分钟未动且无结果），重启中止它
  STALE=$(docker exec jenkins sh -c "[ -f $LOG ] && grep -q '<result>' $J/builds/1/build.xml 2>/dev/null || { M=\$(stat -c %Y $LOG 2>/dev/null || echo 0); [ \$(( $NOW - M )) -gt 180 ] && echo stale; }" 2>/dev/null)
  if [ "$STALE" = "stale" ]; then
    echo "[$(date +%H:%M:%S)] cycle $cycle: stale build -> abort via restart"
    docker restart jenkins >/dev/null; sleep 45
  fi
  if timeout 20 docker exec jenkins git ls-remote https://github.com/LMXC233/yjd.git main >/dev/null 2>&1; then
    echo "[$(date +%H:%M:%S)] cycle $cycle: window open -> reset + restart"
    docker exec -u root jenkins rm -rf $J/builds
    docker exec jenkins sh -c "echo 1 > $J/nextBuildNumber"
    docker restart jenkins >/dev/null
    for t in $(seq 1 66); do
      sleep 10
      R=$(docker exec jenkins sh -c "grep -o '<result>[A-Z]*' $J/builds/1/build.xml 2>/dev/null" | head -1)
      [ -n "$R" ] && break
      # 日志静默超过 4 分钟视为死连接，提前放弃本 cycle
      M=$(docker exec jenkins sh -c "stat -c %Y $LOG 2>/dev/null || echo 0")
      [ $(( $(date +%s) - M )) -gt 240 ] && { echo "[$(date +%H:%M:%S)] cycle $cycle: log silent >4min, giving up this cycle"; break; }
    done
    echo "[$(date +%H:%M:%S)] cycle $cycle: ${R:-NO_RESULT}"
    if [ "$R" = "<result>SUCCESS" ]; then
      echo "BUILD_GREEN"
      docker exec jenkins sh -c "grep -aE 'Reactor|BUILD|docker|compose|healthz|Finished' $LOG | tr -d '\r' | tail -30"
      exit 0
    fi
  else
    echo "[$(date +%H:%M:%S)] cycle $cycle: no window, wait 30s"
    sleep 30
  fi
done
echo GAVE_UP
exit 2
