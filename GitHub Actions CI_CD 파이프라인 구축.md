

# **GitHub Actions, Docker, Slack을 활용한 풀사이클 CI/CD 파이프라인 설계**

### **서론**

#### **개요**

본 보고서는 GitHub Actions를 활용하여 현대적이고 완전한 형태의 CI/CD(지속적 통합/지속적 배포) 파이프라인을 설계하고 구현하기 위한 포괄적인 단계별 가이드를 제공한다.1 이 보고서는 단순한 자동화를 넘어, 자동화된 빌드 및 테스트, Docker 컨테이너화, 상태 보고를 위한 동적 Slack 알림, 그리고 개발 서버로의 통제된 배포를 위한 Slack 내 대화형 수동 승인 게이트를 통합하는 정교한 워크플로우를 구축하는 방법을 다룬다.

#### **전략적 가치**

이 파이프라인의 핵심 목표는 개발 속도와 운영 안정성 사이의 균형을 맞추는 것이다. 반복적인 작업을 자동화하고 "ChatOps" 기반의 수동 승인 단계를 도입함으로써, 개발팀은 배포 대상과 시점에 대한 엄격한 통제를 유지하면서도 소프트웨어 전달 수명 주기를 가속화할 수 있다.3

#### **핵심 기술 개요**

본 가이드에서는 컨테이너화를 위한 Docker 제품군, Slack 연동을 위한 전문 액션, 서버 배포를 위한 SSH 기반 도구 등 공식적으로 검증되었거나 커뮤니티에서 널리 인정받는 GitHub Actions를 활용할 것이다.  
---

### **섹션 1: 상위 수준 아키텍처 및 워크플로우 시각화**

#### **엔드-투-엔드 프로세스 흐름**

전체 파이프라인은 git push 트리거부터 최종 배포까지의 모든 과정을 포함하며, 각 작업(job)의 순서, 의존성, 그리고 GitHub Container Registry(GHCR) 및 Slack과 같은 외부 서비스와의 상호작용 지점을 명확히 정의한다.

#### **워크플로우 단계별 설명**

1. **트리거 (Trigger):** 워크플로우는 main 브랜치에 대한 push 이벤트에 의해 시작된다.5  
2. **1단계: 빌드 (Build):** build 작업이 코드를 컴파일하고, 완료 후 성공/실패 상태를 즉시 Slack으로 알린다.  
3. **2단계: 테스트 (Test):** build 작업이 성공하면 test 작업이 자동화된 테스트를 실행한다. 이 단계 역시 완료 후 결과를 Slack으로 알린다.  
4. **3단계: 패키징 및 게시 (Packaging & Publishing):** 테스트 단계가 성공적으로 완료되면, build-and-push-docker 작업이 Docker 이미지를 빌드하고 Git 메타데이터로 태그를 지정한 후 GHCR에 푸시한다.8  
5. **4단계: 대화형 게이팅 (Interactive Gating):** 패키징 단계에 의존하는 request-deployment-approval 작업은 지정된 Slack 채널에 "승인(Approve)" 및 "거절(Reject)" 버튼이 포함된 메시지를 보내고, 사람의 개입을 기다리며 워크플로우를 일시 중지시킨다.11  
6. **5단계: 지속적 배포 (CD):** deploy-to-dev 작업은 Slack으로부터 "승인" 신호를 받아야만 트리거된다. 승인 후, 개발 서버에 SSH로 연결하여 새로 빌드된 Docker 컨테이너를 배포한다.13  
7. **6단계: 최종 알림 (Final Notification):** 마지막으로, 이전 작업들의 성공 여부와 관계없이 항상 실행되는(if: always()) 독립적인 notify-slack 작업이 전체 워크플로우 실행의 최종 상태(성공 또는 실패)를 Slack에 보고하여 최종 요약 정보를 제공한다.15

#### **핵심 GitHub Actions 개념**

워크플로우 구성에 대한 이해를 돕기 위해 GitHub Actions의 핵심 구성 요소인 workflows, events, jobs, steps, actions, runners에 대해 먼저 설명한다.5

* **작업 의존성을 통한 아키텍처 구축:** GitHub Actions의 작업들은 기본적으로 병렬 실행되지만, needs 키워드를 사용하여 순차적으로 실행되도록 만들 수 있다.5 본 파이프라인에서는 빌드, 테스트, 패키징, 승인, 배포라는 명확한 논리적 단계를 요구하므로, 각 단계를 별도의 독립된 작업으로 구성하고 needs를 통해 의존성을 설정하는 것이 필수적이다. 이는 단순히 코드를 정리하는 차원을 넘어, 파이프라인의 견고성과 논리적 흐름을 보장하는 핵심적인 아키텍처 설계 결정이다. needs 키워드는 각 단계가 이전 단계의 성공을 전제로 진행되도록 강제하는 '접착제' 역할을 한다. 이러한 모듈식 설계는 오류를 조기에 격리하는 데에도 효과적이다. 예를 들어, build 작업에서 실패가 발생하면 후속 작업에 불필요한 리소스를 낭비하지 않고 즉시 파이프라인이 중단된다. 따라서 본 보고서는 단일 스크립트가 아닌, jobs와 needs를 전략적으로 사용하여 실패에 빠르게 대응하고 복원력이 뛰어난 파이프라인을 구축하는 모듈식 접근법을 강조한다.

---

### **섹션 2: 기본 설정: 시크릿, 환경 및 리포지토리 구조**

#### **리포지토리 레이아웃**

유지보수성을 높이기 위해 다음과 같은 표준 디렉토리 구조를 권장한다.

* .github/workflows/deploy.yml: 핵심 워크플로우 파일.2  
* Dockerfile: 프로젝트 루트에 위치하여 Docker 액션이 쉽게 찾을 수 있도록 한다.10  
* scripts/deploy.sh: 배포 로직을 담은 셸 스크립트. SSH 액션에서 이 스크립트를 호출함으로써 관심사를 분리하고 워크플로우 파일을 깔끔하게 유지한다.

#### **GitHub 시크릿 종합 가이드**

보안은 파이프라인 설계에서 가장 중요한 요소 중 하나다. 워크플로우 파일에 민감한 정보를 하드코딩하는 것을 피하기 위해 GitHub의 암호화된 시크릿을 사용해야 한다.19 시크릿은 리포지토리의 Settings \> Secrets and variables \> Actions 메뉴에서 생성할 수 있다.

#### **본 파이프라인에 필요한 시크릿 목록**

* SLACK\_BOT\_TOKEN: Slack 앱의 봇 사용자 OAuth 토큰 (xoxb-로 시작). 메시지 게시 및 상호작용에 사용된다.11  
* SLACK\_APP\_TOKEN: Slack 앱의 앱 레벨 토큰 (xapp-로 시작). 소켓 모드(Socket Mode) 상호작용에 필수적이다.11  
* SLACK\_SIGNING\_SECRET: Slack 앱이 수신하는 요청의 유효성을 검증하는 데 사용되는 서명 시크릿.11  
* SLACK\_CHANNEL\_ID: 알림 및 승인 요청을 보낼 Slack 채널의 ID.11  
* SLACK\_APPROVERS: 배포를 승인할 수 있는 사람들의 Slack 사용자 ID 목록 (쉼표로 구분, 예: U012ABC34DE,U567FGH89IJ).3  
* DEV\_SERVER\_HOST: 개발 서버의 IP 주소 또는 호스트 이름.13  
* DEV\_SERVER\_USER: 개발 서버 SSH 로그인을 위한 사용자 이름.13  
* SSH\_PRIVATE\_KEY: 개발 서버에 암호 없이 인증하기 위한 SSH 개인 키. 이 키는 암호 구문(passphrase) 없이 PEM 형식으로 생성되어야 한다.13

---

### **섹션 3: 지속적 통합 단계: 단계별 빌드, 테스트 및 알림**

이 수정된 섹션에서는 기존의 build-and-test 작업을 build와 test라는 두 개의 개별 작업으로 분리합니다. 각 작업은 완료 시 자체적인 Slack 알림을 보내 파이프라인 진행 상황에 대한 즉각적인 피드백을 제공합니다.

#### **build 작업 구성**

deploy.yml 파일의 첫 번째 작업으로 빌드 단계를 정의합니다.

* name: Build  
* runs-on: ubuntu-latest 2  
* **상세 단계:**  
  1. **코드 체크아웃:** actions/checkout@v4 액션을 사용합니다.2  
  2. **환경 설정:** actions/setup-node@v4를 사용하여 런타임 환경을 설정합니다.7  
  3. **의존성 설치 및 빌드:** npm install 및 npm run build와 같은 명령을 실행합니다.  
  4. **빌드 상태 알림:** if: always() 조건을 사용하여 작업 성공 여부와 관계없이 항상 실행되는 Slack 알림 단계를 추가합니다. 이 알림은 "빌드 작업이 성공/실패했습니다"와 같은 메시지를 보냅니다.15

#### **test 작업 구성**

이 작업은 build 작업의 성공적인 완료에 의존합니다.

* name: Test  
* runs-on: ubuntu-latest  
* needs: build  
* **상세 단계:**  
  1. **코드 체크아웃, 환경 설정, 의존성 설치:** 빌드 작업과 동일한 초기 설정 단계를 반복합니다.  
  2. **테스트 실행:** npm test와 같은 테스트 스위트를 실행합니다. 테스트 실패 시 작업이 중단됩니다.1  
  3. **테스트 상태 알림:** build 작업과 마찬가지로, if: always() 조건을 가진 Slack 알림 단계를 추가하여 테스트 결과(성공/실패)를 즉시 보고합니다.15

---

### **섹션 4: 패키징 단계: Docker 이미지 빌드 및 GHCR 게시**

#### **build-and-push-docker 작업 설계**

이 작업은 이제 test 단계의 성공적인 완료에 의존하도록 정의됩니다.

* name: Build and Push Docker Image  
* runs-on: ubuntu-latest  
* needs: test  
* permissions: GHCR에 이미지를 푸시할 수 있도록 작업에 packages: write 권한을 명시적으로 부여해야 한다.23

#### **Docker Actions Suite 심층 분석**

신뢰성을 확보하고 BuildKit과 같은 최신 기능을 활용하기 위해 공식적으로 검증된 Docker 액션을 사용한다.8

1. **GHCR 로그인:** docker/login-action@v3 액션을 사용하여 GitHub Container Registry에 인증한다. 여기서는 원활한 인증을 위해 특별한 GITHUB\_TOKEN을 사용한다.25  
2. **스마트 태깅을 위한 메타데이터 추출:** 추적 가능성을 위해 매우 중요한 단계다. docker/metadata-action@v5 액션을 사용하여 Git 컨텍스트를 기반으로 관련성 높은 Docker 이미지 태그 세트를 자동으로 생성한다.9  
3. **빌드 및 푸시:** docker/build-push-action@v6 액션을 사용하여 실제 빌드 및 푸시를 수행한다. 메타데이터 액션에서 생성된 태그와 레이블이 이 단계의 입력으로 직접 전달된다.9  
* **동적 태깅을 통한 배포 감사 기능 확보:** 단순히 모든 이미지에 latest 태그를 붙이는 방식은 해당 태그가 가변적이어서 컨테이너 내부에 어떤 버전의 코드가 포함되어 있는지에 대한 정보를 제공하지 못한다. 실제 운영 환경에서 버그가 발견되었을 때, "현재 실행 중인 코드는 정확히 어떤 커밋인가?"라는 질문에 답하기 어렵게 만든다. metadata-action은 Git의 짧은 SHA 해시(예: ghcr.io/my-org/my-repo:a1b2c3d)와 같은 식별자로 이미지에 태그를 지정함으로써 이 문제를 해결한다. 이를 통해 소스 코드 관리 시스템(SCM)과 아티팩트 레지스트리 사이에 불변하고 감사 가능한 연결 고리가 생성된다. 이는 단순한 편의 기능을 넘어, 성숙한 DevOps 문화의 핵심적인 관행이다. 신뢰할 수 있는 롤백(이전 SHA 태그 이미지를 배포)을 가능하게 하고, 디버깅을 단순화하며, 보안 및 규정 준수 감사 요구사항을 충족시키는 데 필수적이다.

#### **주석이 포함된 YAML 예제**

YAML

\- name: Extract Docker metadata  
  id: meta  
  uses: docker/metadata-action@v5  
  with:  
    images: ghcr.io/${{ github.repository }}  
    tags: |  
      type=sha,prefix=,format=short  
      type=ref,event=branch

\- name: Build and push Docker image  
  uses: docker/build-push-action@v6  
  with:  
    context:.  
    push: true  
    tags: ${{ steps.meta.outputs.tags }}  
    labels: ${{ steps.meta.outputs.labels }}

---

### **섹션 5: 고급 커뮤니케이션: 동적 Slack 상태 알림**

#### **파트 A: 상호작용을 위한 Slack 앱 설정**

이 섹션은 알림과 승인 기능 모두를 위한 전제 조건이다.

1. **Slack 앱 생성:** api.slack.com/apps에서 새 앱을 생성하는 단계별 가이드를 따른다.21  
2. **OAuth 범위 설정:** 필요한 권한을 설정한다. 기본 알림에는 chat:write가, 대화형 버튼에는 im:write가 추가로 필요하다.11  
3. **소켓 모드 활성화:** 대화형 기능을 위한 핵심 단계다. 소켓 모드는 GitHub Action이 Slack의 이벤트를 수신할 수 있는 영구적인 WebSocket 연결을 생성하여, 공개적으로 접근 가능한 엔드포인트 없이도 상호작용이 가능하게 만든다.11  
4. **토큰 생성:** 봇 사용자 OAuth 토큰(xoxb-), 앱 레벨 토큰(xapp-), 그리고 서명 시크릿을 생성하여 복사한 후, 앞서 설명한 대로 GitHub 시크릿에 저장한다.11

#### **파트 B: 조건부 알림 구현**

파이프라인의 성공 또는 실패와 무관하게 실행되는 최종 작업 notify-slack을 생성한다.

* name: Notify Slack of Workflow Status  
* runs-on: ubuntu-latest  
* needs: \[build, test, build-and-push-docker, request-deployment-approval, deploy-to-dev\]  
* if: always(): 이 조건은 작업이 항상 실행되도록 보장하여 워크플로우의 최종 상태를 포착한다.15

#### **올바른 Slack 액션 선택**

다양한 Slack 액션이 있지만 15, 대화형 승인 단계와의 일관성을 위해 웹훅이 아닌 봇 토큰을 사용하는 액션을 선택하는 것이 좋다. slackapi/slack-github-action과 같은 액션을 사용하면 단일 Slack 앱으로 모든 상호작용을 처리할 수 있으며, Slack의 Block Kit을 활용하여 풍부하고 구조화된 메시지를 보낼 수 있다.16

#### **상세한 실패 메시지 작성**

job.status와 steps 컨텍스트를 활용하여 실패 시 매우 유용한 정보를 담은 메시지를 생성하는 YAML 설정을 제공한다. 이를 통해 어떤 단계에서 문제가 발생했는지 즉시 파악할 수 있다.16  
---

### **섹션 6: 대화형 게이팅: Slack에서 수동 배포 승인**

#### **아키텍처 선택: Slack 상호작용 vs. GitHub 환경**

수동 승인을 구현하는 두 가지 주요 방법을 비교 분석한다. 사용자의 요구사항은 Slack 기반 솔루션이지만, 전문적인 보고서는 표준적인 대안을 함께 제시하고 비교해야 한다. 이 비교는 사용자가 자신의 팀 문화, 기술적 요구사항, 보안 정책에 기반하여 정보에 입각한 결정을 내릴 수 있도록 돕는다.  
**표 1: 수동 승인 방법론 비교**

| 기능 | GitHub 환경 | 대화형 Slack 버튼 |
| :---- | :---- | :---- |
| **설정 복잡도** | 낮음: 리포지토리 설정에서 구성.\[18, 34\] | 높음: Slack 앱, 소켓 모드, 여러 토큰 및 서드파티 액션 필요.11 |
| **사용자 인터페이스** | GitHub UI: 검토자는 Actions 실행 페이지로 이동해야 함.\[35\] | Slack 채널: 팀의 주요 소통 공간에서 직접 승인 처리.\[36\] |
| **의존성** | 없음 (GitHub 네이티브 기능). | Slack 앱, 소켓 모드, 서드파티 GitHub 액션. |
| **감사 추적** | GitHub 배포 기록 내에 명확하게 통합됨.\[34\] | 비공식적; Slack 채널 기록 및 GitHub Action 로그에 남음. |
| **팀 접근성** | 검토자에게 특정 GitHub 권한 필요.\[18\] | 액션에 정의된 권한(예: 특정 사용자 ID)을 가진 Slack 채널의 누구나 접근 가능.12 |
| **주요 사용 사례** | 감사 추적 및 제어가 SCM/개발 플랫폼 내에 유지되어야 하는 프로세스에 이상적. | 운영 작업을 채팅 인터페이스로 가져오는 ChatOps를 실천하는 팀에 이상적. |

#### **request-deployment-approval 작업 구현**

* name: Request Deployment Approval  
* runs-on: ubuntu-latest  
* needs: build-and-push-docker

#### **액션 구현 (TigerWest/slack-approval)**

TigerWest/slack-approval 액션을 사용하여 완전하고 주석이 달린 예제를 제공한다.12 승인자 목록은 하드코딩하는 대신 SLACK\_APPROVERS라는 GitHub 시크릿을 참조하여 유연성을 확보합니다.

YAML

\- name: Send deployment approval request to Slack  
  uses: TigerWest/slack-approval@v1.1.0  
  id: slack\_approval  
  with:  
    approvers: ${{ secrets.SLACK\_APPROVERS }} \# GitHub 시크릿에서 승인자 목록을 동적으로 가져옵니다.  
    minimumApprovalCount: '1'  
    baseMessagePayload: |  
      {  
        "blocks":  
      }  
  env:  
    SLACK\_APP\_TOKEN: ${{ secrets.SLACK\_APP\_TOKEN }}  
    SLACK\_BOT\_TOKEN: ${{ secrets.SLACK\_BOT\_TOKEN }}  
    SLACK\_SIGNING\_SECRET: ${{ secrets.SLACK\_SIGNING\_SECRET }}  
    SLACK\_CHANNEL\_ID: ${{ secrets.SLACK\_CHANNEL\_ID }}

#### **동작 메커니즘 설명**

이 액션은 소켓 모드 연결을 시작하고 Slack에 메시지를 게시한 후 대기 루프에 들어간다. 워크플로우 실행은 이 시간 동안 '실행 중' 상태를 유지하며 러너 사용 시간을 소모한다. 권한 있는 사용자가 Slack에서 버튼을 클릭하면, 소켓을 통해 이벤트가 다시 전송되고, 액션은 이 신호를 가로채 단계를 성공 또는 실패 처리하여 워크플로우를 계속 진행시키거나 중단시킨다.  
---

### **섹션 7: 지속적 배포 단계: 실제 서버에 배포하기**

#### **deploy-to-dev 작업 생성**

이것은 Slack 승인에 결정적으로 의존하는 마지막 단계다.

* name: Deploy to Development Server  
* runs-on: ubuntu-latest  
* needs: request-deployment-approval

#### **appleboy/ssh-action 사용**

널리 사용되는 appleboy/ssh-action을 사용하여 원격 서버에서 명령을 실행한다.14 이전에 정의한 시크릿을 사용하여 안전하게 구성한다.

#### **운영 수준의 배포 스크립트**

scripts/deploy.sh 파일의 전체 내용을 제공한다. 이 스크립트는 단순한 docker run을 넘어 모범 사례를 포함한다.

Bash

\#\!/bin/bash  
set \-e \# 명령이 0이 아닌 상태로 종료되면 즉시 스크립트를 중단합니다.

IMAGE\_TAG=${1:?Image tag is required}  
IMAGE\_NAME="ghcr.io/${2:?Image name is required}"  
CONTAINER\_NAME="my-app-dev"

echo "--- GitHub Container Registry에 로그인 중 \---"  
echo "${GITHUB\_TOKEN}" | docker login ghcr.io \-u ${GITHUB\_ACTOR} \--password-stdin

echo "--- 새 Docker 이미지 PULL: ${IMAGE\_NAME}:${IMAGE\_TAG} \---"  
docker pull "${IMAGE\_NAME}:${IMAGE\_TAG}"

echo "--- 기존 컨테이너 중지 및 제거 (존재 시) \---"  
docker stop ${CONTAINER\_NAME} |

| true  
docker rm ${CONTAINER\_NAME} |

| true

echo "--- 새 컨테이너 시작 \---"  
docker run \-d \--name ${CONTAINER\_NAME} \-p 8080:80 "${IMAGE\_NAME}:${IMAGE\_TAG}"

echo "--- 오래된 이미지 정리 \---"  
docker image prune \-f

echo "--- 배포 성공\! \---"

#### **스크립트를 워크플로우에 통합**

메타데이터 단계에서 생성된 동적 이미지 태그를 배포 작업으로 전달하고, 이를 다시 스크립트의 인수로 전달하는 방법을 보여준다. 이를 위해서는 작업 간에 데이터를 전달하기 위해 outputs를 사용해야 한다.  
---

### **섹션 8: 전체 워크플로우 및 운영 모범 사례**

#### **최종 deploy.yml 파일**

지금까지 논의된 모든 작업과 단계를 결합한 완전하고 통합된 YAML 파일을 제공한다. 모든 줄에 주석을 달아 그 목적을 설명함으로써, 바로 사용할 수 있는 최종 템플릿 역할을 한다.

#### **고급 주제 및 모범 사례**

* **재사용 가능한 워크플로우:** 여러 리포지토리에서 유지보수성을 높이기 위해 이 파이프라인을 더 작고 재사용 가능한 워크플로우로 분할하는 방법을 간략히 논의한다.1  
* **환경별 구성:** dev, staging, prod 환경에 대해 서로 다른 시크릿 세트를 관리하기 위해 GitHub 환경(Environments)을 사용하는 방법을 설명한다.1  
* **의존성 캐싱:** node\_modules와 같은 의존성에 대한 캐싱을 추가하여 후속 실행 시 CI 단계를 크게 가속화하는 방법을 보여준다.1  
* **보안 강화:** 토큰과 시크릿에 대해 최소 권한 원칙을 적용하고, 웹훅 노출 대신 소켓 모드를 사용하는 것의 보안상 이점을 다시 한번 강조한다.1

---

### **결론**

#### **성과 요약**

본 보고서를 통해 구축된 강력하고 안전하며 효율적인 CI/CD 파이프라인의 성과를 요약한다. ChatOps를 통해 유연한 인간 중심의 승인 프로세스를 통합하면서 전체 개발 수명 주기를 성공적으로 자동화했음을 강조한다.

#### **향후 개선 사항**

자동화된 보안 스캔 통합(예: Docker Scout) 8, 엔드-투-엔드 테스트 추가, 그리고 블루-그린 배포와 같은 무중단 배포 전략을 위한 배포 로직 확장 등 파이프라인을 더욱 성숙시키기 위한 다음 단계를 제안한다.

#### **최종 의견**

이 아키텍처가 개발팀이 더 빠르고 안정적으로 기능을 출시하여 궁극적으로 비즈니스 가치를 창출하는 데 어떻게 기여하는지를 강조하며 보고서를 마무리한다.

#### **참고 자료**

1. CI CD Pipelines with GitHub Actions \- Kerno, 11월 1, 2025에 액세스, [https://www.kerno.io/learn/ci-cd-pipelines-with-github-actions](https://www.kerno.io/learn/ci-cd-pipelines-with-github-actions)  
2. Quickstart for GitHub Actions, 11월 1, 2025에 액세스, [https://docs.github.com/en/actions/get-started/quickstart](https://docs.github.com/en/actions/get-started/quickstart)  
3. CI/CD with GitHub Actions: Deploying Seamlessly to Render | by ..., 11월 1, 2025에 액세스, [https://medium.com/@ryanmambou/ci-cd-with-github-actions-deploying-seamlessly-to-render-bac61db5bd5b](https://medium.com/@ryanmambou/ci-cd-with-github-actions-deploying-seamlessly-to-render-bac61db5bd5b)  
4. Creating Your First CI/CD Pipeline Using GitHub Actions | by Brandon Kindred \- Medium, 11월 1, 2025에 액세스, [https://brandonkindred.medium.com/creating-your-first-ci-cd-pipeline-using-github-actions-81c668008582](https://brandonkindred.medium.com/creating-your-first-ci-cd-pipeline-using-github-actions-81c668008582)  
5. Understanding GitHub Actions \- GitHub Docs, 11월 1, 2025에 액세스, [https://docs.github.com/articles/getting-started-with-github-actions](https://docs.github.com/articles/getting-started-with-github-actions)  
6. Workflow syntax for GitHub Actions, 11월 1, 2025에 액세스, [https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions)  
7. Build a CI/CD workflow with Github Actions, 11월 1, 2025에 액세스, [https://github.com/readme/guides/sothebys-github-actions](https://github.com/readme/guides/sothebys-github-actions)  
8. GitHub Actions \- Docker Docs, 11월 1, 2025에 액세스, [https://docs.docker.com/build/ci/github-actions/](https://docs.docker.com/build/ci/github-actions/)  
9. GitHub Action to build and push Docker images with Buildx, 11월 1, 2025에 액세스, [https://github.com/docker/build-push-action](https://github.com/docker/build-push-action)  
10. push-to-ghcr · Actions · GitHub Marketplace, 11월 1, 2025에 액세스, [https://github.com/marketplace/actions/push-to-ghcr](https://github.com/marketplace/actions/push-to-ghcr)  
11. slack-approval · Actions · GitHub Marketplace · GitHub, 11월 1, 2025에 액세스, [https://github.com/marketplace/actions/slack-approval](https://github.com/marketplace/actions/slack-approval)  
12. tigerwest/slack-approval · Actions · GitHub Marketplace, 11월 1, 2025에 액세스, [https://github.com/marketplace/actions/tigerwest-slack-approval](https://github.com/marketplace/actions/tigerwest-slack-approval)  
13. ssh deploy · Actions · GitHub Marketplace · GitHub, 11월 1, 2025에 액세스, [https://github.com/marketplace/actions/ssh-deploy](https://github.com/marketplace/actions/ssh-deploy)  
14. appleboy/ssh-action: GitHub Actions for executing remote ... \- GitHub, 11월 1, 2025에 액세스, [https://github.com/appleboy/ssh-action](https://github.com/appleboy/ssh-action)  
15. Send Slack Notifications when Github Action fails \- RavSam, 11월 1, 2025에 액세스, [https://www.ravsam.in/blog/send-slack-notification-when-github-actions-fails/](https://www.ravsam.in/blog/send-slack-notification-when-github-actions-fails/)  
16. GitHub Actions Slack integration \- GitHub Marketplace, 11월 1, 2025에 액세스, [https://github.com/marketplace/actions/slack-github-actions-slack-integration](https://github.com/marketplace/actions/slack-github-actions-slack-integration)  
17. Workflows \- GitHub Docs, 11월 1, 2025에 액세스, [https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows)  
18. GitHub Actions now with Manual Approvals \- Cloudlumberjack, 11월 1, 2025에 액세스, [https://cloudlumberjack.com/posts/github-actions-approvals/](https://cloudlumberjack.com/posts/github-actions-approvals/)  
19. Docker Build & Push Action \- GitHub Marketplace, 11월 1, 2025에 액세스, [https://github.com/marketplace/actions/docker-build-push-action](https://github.com/marketplace/actions/docker-build-push-action)  
20. Deploying to a Server with GitHub Actions using ssh | by Balazs Kocsis \- Medium, 11월 1, 2025에 액세스, [https://medium.com/@balazskocsis/deploying-to-a-server-with-github-actions-a-deep-dive-e8558e83a4d7](https://medium.com/@balazskocsis/deploying-to-a-server-with-github-actions-a-deep-dive-e8558e83a4d7)  
21. GitHub Actions Notifier for Slack \- GitHub Marketplace, 11월 1, 2025에 액세스, [https://github.com/marketplace/actions/github-actions-notifier-for-slack](https://github.com/marketplace/actions/github-actions-notifier-for-slack)  
22. Continuous integration \- GitHub Docs, 11월 1, 2025에 액세스, [https://docs.github.com/en/actions/get-started/continuous-integration](https://docs.github.com/en/actions/get-started/continuous-integration)  
23. Build Docker Image and Push to GHCR, Docker Hub, or AWS ECR · Actions \- GitHub, 11월 1, 2025에 액세스, [https://github.com/marketplace/actions/build-docker-image-and-push-to-ghcr-docker-hub-or-aws-ecr](https://github.com/marketplace/actions/build-docker-image-and-push-to-ghcr-docker-hub-or-aws-ecr)  
24. Automate Docker Image Builds and Push to GitHub Registry Using GitHub Actions, 11월 1, 2025에 액세스, [https://dev.to/ken\_mwaura1/automate-docker-image-builds-and-push-to-github-registry-using-github-actions-4h20](https://dev.to/ken_mwaura1/automate-docker-image-builds-and-push-to-github-registry-using-github-actions-4h20)  
25. Push to multiple registries with GitHub Actions \- Docker Docs, 11월 1, 2025에 액세스, [https://docs.docker.com/build/ci/github-actions/push-multi-registries/](https://docs.docker.com/build/ci/github-actions/push-multi-registries/)  
26. Publishing Docker images \- GitHub Docs, 11월 1, 2025에 액세스, [https://docs.github.com/actions/guides/publishing-docker-images](https://docs.github.com/actions/guides/publishing-docker-images)  
27. Slack Notify Deployment · Actions · GitHub Marketplace, 11월 1, 2025에 액세스, [https://github.com/marketplace/actions/slack-notify-deployment](https://github.com/marketplace/actions/slack-notify-deployment)  
28. Notify Slack Action \- GitHub Marketplace, 11월 1, 2025에 액세스, [https://github.com/marketplace/actions/notify-slack-action](https://github.com/marketplace/actions/notify-slack-action)  
29. Post Workflow Status To Slack · Actions · GitHub Marketplace, 11월 1, 2025에 액세스, [https://github.com/marketplace/actions/post-workflow-status-to-slack](https://github.com/marketplace/actions/post-workflow-status-to-slack)  
30. Fix GitHub-Slack Notifications Not Sending \- PullNotifier Blog, 11월 1, 2025에 액세스, [https://blog.pullnotifier.com/blog/fix-github-slack-notifications-not-sending](https://blog.pullnotifier.com/blog/fix-github-slack-notifications-not-sending)  
31. Slack Notify · Actions · GitHub Marketplace, 11월 1, 2025에 액세스, [https://github.com/marketplace/actions/slack-notify](https://github.com/marketplace/actions/slack-notify)  
32. slackapi/slack-github-action: Send data into Slack using this GitHub Action\! \- GitHub, 11월 1, 2025에 액세스, [https://github.com/slackapi/slack-github-action](https://github.com/slackapi/slack-github-action)  
33. Integration of GitHub Actions Slack Notifications \- Suptask, 11월 1, 2025에 액세스, [https://www.suptask.com/blog/github-actions-slack-notifications](https://www.suptask.com/blog/github-actions-slack-notifications)