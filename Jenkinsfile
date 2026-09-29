// yjd CI/CD 流水线（ADR-0008：自建 Jenkins@WSL，push 轮询触发）
// 仓库 public，GitHub 拉取无需凭据；本流水线不涉及生产 registry（随 monolith ticket 接入）。
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '30'))
    }

    // WSL 无公网入口：Poll SCM 每分钟轮询，满足「push 后 ≤2 分钟触发」
    triggers {
        pollSCM('* * * * *')
    }

    environment {
        APP_IMAGE = 'yjd-auth-boot'
        COMPOSE_FILE = 'deploy/wsl/docker-compose.yml'
    }

    stages {
        stage('版本解析') {
            steps {
                script {
                    // 避免依赖 lightweight checkout 是否导出 GIT_COMMIT，直接从工作区取
                    env.SHORT_SHA = sh(returnStdout: true, script: 'git rev-parse --short=7 HEAD').trim()
                    currentBuild.description = "${env.APP_IMAGE}:${env.SHORT_SHA}"
                }
            }
        }

        stage('mvn verify') {
            steps {
                dir('backend') {
                    sh 'mvn -B -ntp verify'
                }
            }
        }

        stage('构建镜像') {
            steps {
                sh 'docker build -f backend/yjd-auth-boot/Dockerfile -t ${APP_IMAGE}:${SHORT_SHA} -t ${APP_IMAGE}:latest backend/yjd-auth-boot/target'
            }
        }

        stage('WSL Compose 部署') {
            steps {
                sh 'YJD_TAG=${SHORT_SHA} docker compose -f ${COMPOSE_FILE} -p yjd up -d --force-recreate'
                script {
                    def hostIp = sh(returnStdout: true, script: "docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}'").trim()
                    retry(20) {
                        sleep(3)
                        sh "curl -fsS http://${hostIp}:8080/healthz"
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
