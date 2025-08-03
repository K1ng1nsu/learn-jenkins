## Jenkins와 GitHub 연동하여 Docker 컨테이너로 자동 배포하기

Jenkins와 GitHub를 연동하여 코드가 새로 올라올 때마다 Docker 컨테이너로 자동으로 배포하는 방법을 설명해 드릴게요. 이 과정은 크게 **Jenkins 설정**, **GitHub 웹훅 설정**, 그리고 **Jenkins 파이프라인 구성**으로 나눌 수 있습니다.

### 1. Jenkins 준비

먼저 Jenkins 서버에 필요한 플러그인과 도구가 설치되어 있어야 합니다.

- **Git 플러그인**: GitHub에서 코드를 가져오기 위해 필요합니다.
- **Docker 설치**: Jenkins 서버 또는 Jenkins가 접근할 수 있는 곳에 Docker가 설치되어 있어야 합니다. (만약 Jenkins 빌드 에이전트에서 Docker를 실행한다면 해당 에이전트에 Docker가 설치되어 있어야 합니다.)
- **Pipeline 플러그인**: Jenkinsfile을 사용하여 파이프라인을 정의할 때 필요합니다. (기본적으로 설치되어 있을 가능성이 높습니다.)
- **Docker Pipeline 플러그인 (선택 사항)**: Jenkinsfile 내에서 Docker 관련 명령어를 더 쉽게 사용할 수 있도록 도와줍니다.

플러그인 설치는 Jenkins 대시보드에서 **Jenkins 관리 \> 플러그인 관리**로 이동하여 "설치 가능" 탭에서 검색 및 설치할 수 있습니다.

### 2\. GitHub 설정 (웹훅)

GitHub 저장소에 코드가 푸시될 때 Jenkins에게 알림을 보내도록 웹훅을 설정해야 합니다.

1.  **GitHub 저장소**로 이동합니다.
2.  **Settings (설정)** 탭을 클릭합니다.
3.  좌측 메뉴에서 \*\*Webhooks (웹훅)\*\*을 클릭합니다.
4.  **Add webhook (웹훅 추가)** 버튼을 클릭합니다.
5.  **Payload URL**: 여기에 Jenkins 서버의 웹훅 URL을 입력합니다. 일반적으로 `http://[Jenkins-서버-IP-또는-도메인]:[Jenkins-포트]/github-webhook/` 형식입니다.
    - 예: `http://your-jenkins-server.com:8080/github-webhook/`
6.  **Content type**: `application/json`으로 설정합니다.
7.  **Secret**: (선택 사항) 보안 강화를 위해 시크릿 키를 설정할 수 있습니다. Jenkins 파이프라인에서 이 시크릿 키를 사용하여 요청의 유효성을 검사할 수 있습니다.
8.  **Which events would you like to trigger this webhook?**: **Just the push event.** 를 선택하거나, 필요한 다른 이벤트를 선택합니다.
9.  **Add webhook** 버튼을 클릭하여 웹훅을 추가합니다.

### 3\. Jenkins 파이프라인 프로젝트 생성

이제 Jenkins에서 파이프라인 프로젝트를 생성하고 GitHub 연동 및 Docker 배포 로직을 구성합니다.

1.  Jenkins 대시보드에서 \*\*새로운 Item (새로운 항목)\*\*을 클릭합니다.
2.  Item 이름 입력 후 \*\*Pipeline (파이프라인)\*\*을 선택하고 \*\*OK (확인)\*\*를 클릭합니다.

### 4\. Jenkins 파이프라인 구성 (Jenkinsfile)

생성된 파이프라인 프로젝트 설정 페이지에서 **Pipeline** 섹션으로 스크롤하여 **Definition**을 **Pipeline script from SCM**으로 변경합니다.

- **SCM**: **Git**을 선택합니다.
- **Repository URL**: GitHub 저장소의 URL을 입력합니다. (예: `https://github.com/your-username/your-repo.git`)
- **Credentials**: GitHub 저장소가 비공개인 경우, 접근할 수 있는 **SSH Key** 또는 **Username and Password** 형태의 자격 증명을 추가해야 합니다.
- **Branches to build**: `*/main` 또는 `*/master` (배포하려는 브랜치)
- **Script Path**: `Jenkinsfile` (기본값, 저장소 루트에 Jenkinsfile이 있다면 그대로 둡니다.)

이제 GitHub 저장소의 루트에 `Jenkinsfile`을 생성하고 다음과 같이 내용을 작성합니다.

```groovy
pipeline {
    agent any // 빌드를 실행할 Jenkins 에이전트 (any는 아무 에이전트나 사용)

    environment {
        // Docker 이미지 이름 설정
        DOCKER_IMAGE_NAME = "my-app"
        // Docker Hub 사용자 이름 (선택 사항, Docker Hub에 푸시할 경우 필요)
        // DOCKER_HUB_USERNAME = "your-dockerhub-username"
    }

    stages {
        stage('Checkout Code') {
            steps {
                // GitHub에서 소스 코드 체크아웃
                git branch: 'main', credentialsId: 'your-github-credentials-id', url: 'https://github.com/your-username/your-repo.git'
                // 'your-github-credentials-id'는 Jenkins에 등록된 GitHub 자격증명의 ID입니다.
                // CredentialsId는 Jenkins > Jenkins 관리 > Credentials > System > Global credentials 에서 확인할 수 있습니다.
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Dockerfile이 있는 디렉토리로 이동 (보통 프로젝트 루트)
                    // 현재 디렉토리에서 Docker 이미지를 빌드합니다.
                    sh "docker build -t ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} ."
                    // ${BUILD_NUMBER}는 Jenkins 빌드 번호를 사용하여 이미지 태그를 유니크하게 만듭니다.
                    // 필요에 따라 'latest' 태그도 추가할 수 있습니다.
                    sh "docker tag ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER} ${DOCKER_IMAGE_NAME}:latest"
                }
            }
        }

        stage('Stop & Remove Old Container') {
            steps {
                script {
                    // 기존에 실행 중인 컨테이너가 있다면 중지하고 제거합니다.
                    // 컨테이너 이름은 자유롭게 지정할 수 있습니다.
                    def containerId = sh(returnStdout: true, script: "docker ps -aq --filter name=^my-app-container$").trim()
                    if (containerId) {
                        sh "docker stop ${containerId}"
                        sh "docker rm ${containerId}"
                    } else {
                        echo "No existing container 'my-app-container' found."
                    }
                }
            }
        }

        stage('Run New Docker Container') {
            steps {
                script {
                    // 새로운 Docker 컨테이너를 실행합니다.
                    // -p 80:8080 : 호스트의 80번 포트를 컨테이너의 8080번 포트에 매핑
                    // --name my-app-container : 컨테이너 이름 지정
                    sh "docker run -d -p 80:8080 --name my-app-container ${DOCKER_IMAGE_NAME}:latest"
                }
            }
        }

        // 선택 사항: Docker Hub에 이미지 푸시
        // stage('Push Docker Image to Docker Hub') {
        //     steps {
        //         script {
        //             // Docker Hub 로그인 (Jenkins Credentials에 Docker Hub 자격증명 등록 필요)
        //             // Docker Hub 자격증명 ID는 'docker-hub-credentials'로 가정합니다.
        //             // sh "echo ${env.DOCKER_HUB_PASSWORD} | docker login -u ${env.DOCKER_HUB_USERNAME} --password-stdin" // 보안상 env 사용 권장
        //             withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', passwordVariable: 'DOCKER_HUB_PASSWORD', usernameVariable: 'DOCKER_HUB_USERNAME')]) {
        //                 sh "docker login -u ${DOCKER_HUB_USERNAME} -p ${DOCKER_HUB_PASSWORD}"
        //                 sh "docker push ${DOCKER_HUB_USERNAME}/${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}"
        //                 sh "docker push ${DOCKER_HUB_USERNAME}/${DOCKER_IMAGE_NAME}:latest"
        //             }
        //         }
        //     }
        // }
    }

    post {
        always {
            // 빌드 완료 후 항상 실행되는 블록 (성공/실패 여부와 관계없이)
            echo 'Pipeline finished.'
        }
        success {
            echo 'Deployment successful!'
        }
        failure {
            echo 'Deployment failed!'
        }
    }
}
```

**`Jenkinsfile` 설명:**

- **`agent any`**: 어떤 Jenkins 에이전트에서든 이 파이프라인을 실행합니다.
- **`environment`**: 파이프라인 전역에서 사용할 환경 변수를 정의합니다.
- **`stages`**: 파이프라인의 각 단계를 정의합니다.
  - **`Checkout Code`**: GitHub에서 최신 소스 코드를 가져옵니다. `credentialsId`는 Jenkins에 등록된 GitHub 계정 자격 증명의 ID입니다.
  - **`Build Docker Image`**: 프로젝트 루트에 있는 `Dockerfile`을 사용하여 Docker 이미지를 빌드합니다. `$BUILD_NUMBER`는 Jenkins 빌드 번호를 사용하여 고유한 이미지 태그를 생성합니다.
  - **`Stop & Remove Old Container`**: 이전에 실행 중이던 동일한 이름의 Docker 컨테이너를 중지하고 제거하여 새로운 컨테이너가 실행될 수 있도록 합니다. `my-app-container`는 컨테이너 이름으로 원하는 대로 변경할 수 있습니다.
  - **`Run New Docker Container`**: 새로 빌드된 Docker 이미지를 사용하여 새 컨테이너를 실행합니다. `-d`는 백그라운드에서 실행, `-p`는 포트 매핑, `--name`은 컨테이너 이름입니다.
- **`post`**: 파이프라인 실행 완료 후 (성공 또는 실패 여부에 따라) 실행될 작업을 정의합니다.

### 5\. Dockerfile 작성

프로젝트의 루트 디렉토리에 다음과 같은 간단한 `Dockerfile`을 작성해야 합니다. (예시: Node.js 애플리케이션)

```dockerfile
# Dockerfile 예시 (Node.js 애플리케이션)
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 8080

CMD ["node", "server.js"]
```

`Dockerfile`은 애플리케이션의 종류에 따라 적절하게 작성해야 합니다.

### 6\. Jenkins 자격 증명 (Credentials) 설정

GitHub 비공개 저장소에 접근하거나 Docker Hub에 이미지를 푸시하려면 Jenkins에 해당 자격 증명을 등록해야 합니다.

1.  Jenkins 대시보드에서 \*\*Jenkins 관리 \> Credentials (자격 증명) \> System \> Global credentials (global)\*\*을 클릭합니다.
2.  \*\*Add Credentials (자격 증명 추가)\*\*를 클릭합니다.
3.  **Kind (종류)**:
    - **Username with password**: GitHub 계정 (이름/비밀번호), Docker Hub 계정 등에 사용.
    - **SSH Username with private key**: GitHub SSH 키에 사용.
4.  ID를 지정하고 (예: `your-github-credentials-id`, `docker-hub-credentials`) 필요한 정보를 입력합니다. 이 ID를 `Jenkinsfile`에서 사용합니다.

### 7\. 테스트 및 확인

이제 GitHub 저장소에 코드를 푸시하여 자동 배포가 정상적으로 작동하는지 확인합니다.

1.  GitHub 저장소에 변경 사항을 푸시합니다.
2.  Jenkins 대시보드에서 해당 파이프라인 프로젝트의 빌드가 자동으로 시작되는지 확인합니다.
3.  빌드 로그를 확인하여 각 단계(Checkout, Build Docker Image, Run New Docker Container)가 성공적으로 완료되는지 확인합니다.
4.  Jenkins 서버에서 `docker ps` 명령어를 실행하여 새로운 컨테이너가 정상적으로 실행 중인지 확인합니다.
5.  브라우저에서 `http://[Jenkins-서버-IP-또는-도메인]:[매핑된-호스트-포트]` (위 예시에서는 80)로 접속하여 애플리케이션이 잘 동작하는지 확인합니다.

이 설정 과정을 통해 GitHub에 코드가 업데이트될 때마다 Jenkins가 자동으로 Docker 컨테이너를 빌드하고 배포하는 CI/CD 파이프라인을 구축할 수 있습니다.
