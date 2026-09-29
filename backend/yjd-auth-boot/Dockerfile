# thin 打包镜像：构建上下文 = backend/yjd-auth-boot/target（mvn verify 已产出 yjd-auth-boot.jar）
FROM eclipse-temurin:21-jre

WORKDIR /app
COPY yjd-auth-boot.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
