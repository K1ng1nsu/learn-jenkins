FROM jenkins/jenkins:lts-jdk17

# root 권한으로 실행
USER root

# Docker 설치
RUN apt-get update && apt-get install -y \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# jenkins 사용자를 docker 그룹에 추가
#RUN groupadd -g 999 docker \
#    && usermod -aG docker jenkins

# Jenkins 실행
USER jenkins
