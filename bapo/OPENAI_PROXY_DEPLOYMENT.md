# FitFace OpenAI Proxy 배포 문서

이 문서는 FitFace 앱의 OpenAI API 모드를 NAS 또는 개인 서버에서 운영하기 위한 배포 절차를 정리한다.

FitFace 앱은 OpenAI API key를 앱 안에 저장하지 않는다. 앱은 별도 프록시 서버로 요청을 보내고, 프록시 서버가 서버 환경변수에 저장된 `OPENAI_API_KEY`로 OpenAI API를 호출한다.

```text
FitFace 앱
  -> FitFace OpenAI Proxy
  -> OpenAI API
```

프록시 서버 진입점:

```text
bin/fitface_openai_proxy.dart
```

프록시 엔드포인트:

```text
GET  /health
POST /ai/snapshot/analyze
POST /ai/snapshots/compare
POST /ai/personal-color
```

## 권장 방식

NAS 또는 개인서버에는 Docker Compose 배포를 권장한다.

이유:

- Synology/QNAP 같은 NAS는 일반 Ubuntu가 아니어서 Dart SDK 직접 설치가 번거롭다.
- Docker image 안에서 Dart SDK를 사용하므로 NAS 호스트에 Dart SDK를 직접 설치하지 않아도 된다.
- 재시작, 로그 확인, 업데이트가 쉽다.
- 운영 서버에는 OpenAI API key만 환경변수로 주입하면 된다.

권장 우선순위:

```text
1. Docker Compose 배포
2. Ubuntu/Debian 서버에 Dart SDK 설치 후 systemd 서비스 등록
3. Windows/macOS에서 임시 실행
```

## 보안 원칙

현재 프록시는 별도 사용자 인증 토큰이 없다. 따라서 인터넷에 `http://공인IP:8787` 형태로 직접 공개하면 안 된다.

반드시 지킬 것:

- `OPENAI_API_KEY`를 앱에 넣지 않는다.
- `.env` 파일을 git에 커밋하지 않는다.
- LAN 안에서만 쓸 경우 NAS/서버의 사설 IP로 접속한다.
- 외부에서 쓸 경우 Tailscale/WireGuard 같은 VPN을 우선 사용한다.
- 부득이하게 인터넷에 공개할 경우 HTTPS reverse proxy와 별도 인증 토큰 기능을 추가한 뒤 공개한다.
- OpenAI dashboard에서 usage limit를 설정한다.
- API key가 노출됐다고 의심되면 즉시 revoke/rotate한다.

## 환경변수

프록시 서버는 아래 환경변수를 읽는다.

```text
OPENAI_API_KEY=필수, OpenAI API key
OPENAI_MODEL=선택, 기본값 gpt-5.4-mini
FITFACE_PROXY_HOST=선택, 기본값 127.0.0.1
FITFACE_PROXY_PORT=선택, 기본값 8787
FITFACE_PROXY_MAX_BODY_BYTES=선택, 기본값 12582912
FITFACE_PROXY_MAX_IMAGES=선택, 기본값 3
```

NAS/개인서버에서 휴대폰 앱이 접근해야 하므로 운영 배포에서는 보통 이렇게 둔다.

```text
FITFACE_PROXY_HOST=0.0.0.0
FITFACE_PROXY_PORT=8787
```

환경변수 등록 방식은 배포 방식에 따라 다르다.

```text
Docker Compose 배포:
  프로젝트 루트 .env 파일을 만들고 docker-compose.yml의 env_file로 주입한다.

Ubuntu/Debian 직접 실행:
  .env 파일은 필수가 아니다.
  테스트 실행은 shell export로 주입한다.
  운영 실행은 /etc/fitface-openai-proxy.env 파일을 만들고 systemd EnvironmentFile로 주입한다.
```

중요: Dart 앱은 프로젝트 루트의 `.env` 파일을 자동으로 읽지 않는다. `dart run bin/fitface_openai_proxy.dart`만 실행하면 `.env` 파일이 있어도 적용되지 않는다. 반드시 shell, Docker Compose, systemd 중 하나가 환경변수로 주입해야 한다.

### 환경변수 작성 규칙

환경변수 파일에 값을 직접 쓸 때는 따옴표 없이 쓰는 것을 권장한다.

권장:

```text
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-5.4-mini
FITFACE_PROXY_HOST=0.0.0.0
FITFACE_PROXY_PORT=8787
```

피해야 할 예:

```text
FITFACE_PROXY_HOST="0.0.0.0"
FITFACE_PROXY_PORT="8787"
```

PowerShell에서 아래처럼 쓰는 것은 괜찮다. 이때의 따옴표는 PowerShell 문법이고 값에 포함되지 않는다.

```powershell
$env:FITFACE_PROXY_HOST="0.0.0.0"
```

하지만 아래처럼 따옴표를 한 번 더 넣으면 값 자체가 `"0.0.0.0"`이 되어 서버가 시작하지 못할 수 있다.

```powershell
$env:FITFACE_PROXY_HOST='"0.0.0.0"'
```

최신 프록시 코드는 바깥쪽 따옴표를 한 번 제거하도록 보완되어 있지만, 배포 문서와 운영 환경에서는 따옴표 없는 값을 기준으로 관리한다.

### Dart SDK 직접 설치 시 `.env` 처리 기준

Ubuntu/Debian 서버에 Dart SDK를 직접 설치하는 것과 `.env` 파일을 등록하는 것은 별개의 단계다.

정리하면 다음과 같다.

```text
Dart SDK 설치:
  프록시 프로그램을 실행하기 위한 런타임 설치다.
  .env 등록은 필요 없다.

테스트 실행:
  .env 파일 없이 shell에서 export OPENAI_API_KEY=... 형태로 넣고 실행할 수 있다.
  터미널을 닫거나 서버가 재부팅되면 사라지므로 장기 운영에는 맞지 않는다.

운영 실행:
  프로젝트 루트 .env 대신 /etc/fitface-openai-proxy.env 파일을 만든다.
  systemd unit의 EnvironmentFile=/etc/fitface-openai-proxy.env 설정으로 읽게 한다.

Docker Compose 실행:
  docker-compose.yml의 env_file 설정이 프로젝트 루트 .env를 읽어 컨테이너에 주입한다.
```

따라서 Ubuntu/Debian에 Dart SDK를 직접 설치한다고 해서 `.env`를 반드시 프로젝트 루트에 만들 필요는 없다. 단, 프록시가 OpenAI API를 호출하려면 실행 시점에는 반드시 `OPENAI_API_KEY`가 환경변수로 들어가 있어야 한다.

## 방식 1. Docker Compose 배포

### 1. 서버에 소스 받기

```bash
git clone https://github.com/kjs3047/fitface.git
cd fitface
git checkout main
git pull --ff-only
```

### 2. `.env` 파일 만들기

프로젝트 루트에 `.env` 파일을 만든다.

```bash
OPENAI_API_KEY=여기에_OpenAI_API_Key
OPENAI_MODEL=gpt-5.4-mini
FITFACE_PROXY_HOST=0.0.0.0
FITFACE_PROXY_PORT=8787
FITFACE_PROXY_MAX_BODY_BYTES=12582912
FITFACE_PROXY_MAX_IMAGES=3
```

권한을 줄일 수 있는 Linux 계열 서버라면 다음처럼 제한한다.

```bash
chmod 600 .env
```

### 3. `Dockerfile` 만들기

프로젝트 루트에 `Dockerfile`을 만든다.

```dockerfile
FROM dart:stable AS build
WORKDIR /app

COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/fitface_openai_proxy.dart -o /app/fitface_openai_proxy

FROM debian:bookworm-slim
WORKDIR /app

COPY --from=build /app/fitface_openai_proxy /app/fitface_openai_proxy

EXPOSE 8787
CMD ["/app/fitface_openai_proxy"]
```

### 4. `docker-compose.yml` 만들기

프로젝트 루트에 `docker-compose.yml`을 만든다.

```yaml
services:
  fitface-openai-proxy:
    build: .
    container_name: fitface-openai-proxy
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "8787:8787"
```

### 5. 실행

```bash
docker compose up -d --build
```

### 6. 상태 확인

```bash
docker compose ps
docker compose logs -f fitface-openai-proxy
```

서버에서 health 확인:

```bash
curl http://127.0.0.1:8787/health
```

정상 응답:

```json
{"ok":true}
```

같은 Wi-Fi 안의 다른 PC 또는 휴대폰에서:

```bash
curl http://NAS_IP:8787/health
```

예:

```bash
curl http://192.168.0.50:8787/health
```

## 방식 2. Synology NAS Container Manager

Synology DSM에서는 Dart SDK 직접 설치보다 Container Manager 배포를 권장한다.

절차:

1. Synology `Container Manager` 설치
2. NAS 공유 폴더에 FitFace repo 업로드 또는 git clone
3. 프로젝트 루트에 `.env` 작성
4. 프로젝트 루트에 `Dockerfile` 작성
5. 프로젝트 루트에 `docker-compose.yml` 작성
6. Container Manager에서 Project 생성
7. compose 파일 선택 후 실행
8. NAS 방화벽에서 TCP `8787` 허용
9. 앱의 OpenAI 프록시 주소에 `http://NAS_IP:8787` 입력
10. 앱에서 `연결 테스트`

Synology NAS IP가 `192.168.0.20`이면 앱 설정 값은 다음과 같다.

```text
http://192.168.0.20:8787
```

## 방식 3. Ubuntu/Debian 서버에 Dart SDK 직접 설치

Ubuntu/Debian 서버라면 공식 apt repository로 Dart SDK를 설치할 수 있다.

이 방식에서 프로젝트 루트 `.env` 파일은 필수가 아니다. 아래처럼 터미널에서 `export`로 환경변수를 넣으면 프록시를 바로 실행할 수 있다. 다만 `export` 방식은 현재 shell 세션에만 적용되므로 테스트용이다.

운영 서버에서 계속 켜둘 때는 다음 섹션의 systemd 방식처럼 `/etc/fitface-openai-proxy.env`를 만들고 `EnvironmentFile=/etc/fitface-openai-proxy.env`로 읽게 하는 것을 권장한다.

즉, Dart SDK 설치 과정에는 `.env` 등록이 필요하지 않다. `.env` 또는 환경변수 파일은 프록시 프로세스를 실행할 때 `OPENAI_API_KEY`를 전달하기 위한 설정이다.

### 1. 필수 패키지 설치

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https wget gpg
```

### 2. Google Linux signing key 추가

```bash
wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub \
  | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
```

### 3. Dart apt repository 추가

`amd64` 서버 기준:

```bash
echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' \
  | sudo tee /etc/apt/sources.list.d/dart_stable.list
```

ARM64 서버라면 `arch=arm64`로 바꾼다.

```bash
echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=arm64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' \
  | sudo tee /etc/apt/sources.list.d/dart_stable.list
```

### 4. Dart 설치

```bash
sudo apt-get update
sudo apt-get install -y dart
```

설치 확인:

```bash
dart --version
```

### 5. FitFace 프록시 실행

테스트용 임시 실행:

```bash
git clone https://github.com/kjs3047/fitface.git /opt/fitface
cd /opt/fitface
git checkout main
git pull --ff-only
dart pub get

export OPENAI_API_KEY="여기에_OpenAI_API_Key"
export OPENAI_MODEL="gpt-5.4-mini"
export FITFACE_PROXY_HOST="0.0.0.0"
export FITFACE_PROXY_PORT="8787"

dart run bin/fitface_openai_proxy.dart
```

이 방식은 `.env` 파일 없이 동작한다. 대신 터미널을 닫거나 서버가 재부팅되면 환경변수와 프로세스가 사라진다.

## 방식 4. systemd 서비스 등록

Ubuntu/Debian 서버에서 계속 켜두려면 systemd 서비스로 등록한다.

systemd 방식에서는 프로젝트 루트 `.env`가 아니라 `/etc/fitface-openai-proxy.env`를 사용한다. 이 파일은 git repo 바깥에 있으므로 API key를 실수로 커밋할 위험이 낮고, `chmod 600`으로 권한을 제한하기 쉽다.

### 1. 서비스 사용자 생성

```bash
sudo useradd --system --home /opt/fitface --shell /usr/sbin/nologin fitface
sudo chown -R fitface:fitface /opt/fitface
```

### 2. 환경변수 파일 생성

```bash
sudo nano /etc/fitface-openai-proxy.env
```

내용:

```text
OPENAI_API_KEY=여기에_OpenAI_API_Key
OPENAI_MODEL=gpt-5.4-mini
FITFACE_PROXY_HOST=0.0.0.0
FITFACE_PROXY_PORT=8787
FITFACE_PROXY_MAX_BODY_BYTES=12582912
FITFACE_PROXY_MAX_IMAGES=3
```

권한 제한:

```bash
sudo chmod 600 /etc/fitface-openai-proxy.env
```

### 3. systemd unit 생성

```bash
sudo nano /etc/systemd/system/fitface-openai-proxy.service
```

내용:

```ini
[Unit]
Description=FitFace OpenAI Proxy
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/opt/fitface
EnvironmentFile=/etc/fitface-openai-proxy.env
ExecStart=/usr/bin/dart run bin/fitface_openai_proxy.dart
Restart=always
RestartSec=3
User=fitface
Group=fitface

[Install]
WantedBy=multi-user.target
```

### 4. 서비스 시작

```bash
sudo systemctl daemon-reload
sudo systemctl enable fitface-openai-proxy
sudo systemctl start fitface-openai-proxy
```

상태 확인:

```bash
sudo systemctl status fitface-openai-proxy
journalctl -u fitface-openai-proxy -f
curl http://127.0.0.1:8787/health
```

## 방식 5. Windows에서 임시 실행

개발 PC나 테스트 PC에서 임시로 실행할 때 사용한다.

Windows에서 Dart SDK를 따로 설치해야 한다면 관리자 PowerShell에서 Chocolatey로 설치한다.

```powershell
choco install dart-sdk
dart --version
```

Flutter SDK가 이미 설치되어 있고 `dart --version`이 동작한다면 별도 설치가 필요 없다.

FitFace 프록시 실행:

```powershell
cd C:\dev\12121212

$env:OPENAI_API_KEY="여기에_OpenAI_API_Key"
$env:OPENAI_MODEL="gpt-5.4-mini"
$env:FITFACE_PROXY_HOST="0.0.0.0"
$env:FITFACE_PROXY_PORT="8787"

dart run bin/fitface_openai_proxy.dart
```

`.env.local` 파일을 만들어 두고 PowerShell에서 읽어 실행할 수도 있다.

`.env.local` 예:

```text
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-5.4-mini
FITFACE_PROXY_HOST=0.0.0.0
FITFACE_PROXY_PORT=8787
```

PowerShell에서 `.env.local` 로딩:

```powershell
cd C:\dev\12121212

Get-Content .env.local | Where-Object { $_ -match '^\s*[^#].+=' } | ForEach-Object {
  $k, $v = $_ -split '=', 2
  $value = $v.Trim()
  if (
    ($value.StartsWith('"') -and $value.EndsWith('"')) -or
    ($value.StartsWith("'") -and $value.EndsWith("'"))
  ) {
    $value = $value.Substring(1, $value.Length - 2).Trim()
  }
  Set-Item -Path "Env:$($k.Trim())" -Value $value
}

dart run bin/fitface_openai_proxy.dart
```

PC에서 먼저 확인:

```powershell
Invoke-RestMethod http://127.0.0.1:8787/health
```

PC IP가 `192.168.202.18`이면 휴대폰 앱에는 다음을 입력한다.

```text
http://192.168.202.18:8787
```

휴대폰이 연결하려면 Windows Defender Firewall에서 TCP `8787` 인바운드가 허용되어 있어야 한다. PC에서는 `127.0.0.1`로 성공하지만 휴대폰에서 실패한다면 방화벽, PC IP, 같은 Wi-Fi/VPN 여부를 먼저 확인한다.

## 앱 설정

FitFace 앱에서:

1. 설정
2. AI 설정
3. AI 엔진을 `OpenAI API`로 선택
4. 클라우드 AI 사용 동의 ON
5. OpenAI 프록시 주소 입력
6. `연결 테스트`
7. 후보 분석/후보 비교/퍼스널 컬러 분석 테스트

LAN 안의 NAS:

```text
http://192.168.0.20:8787
```

개인 서버:

```text
http://192.168.0.50:8787
```

Tailscale:

```text
http://100.x.x.x:8787
```

도메인과 HTTPS reverse proxy를 붙인 경우:

```text
https://fitface-proxy.example.com
```

## 외부 접속 구성

### 권장: Tailscale 또는 WireGuard

집 밖에서도 쓰려면 Tailscale/WireGuard 같은 VPN을 권장한다.

```text
휴대폰
  -> Tailscale/WireGuard
  -> NAS/개인서버의 FitFace OpenAI Proxy
```

앱 프록시 주소 예:

```text
http://100.80.12.34:8787
```

장점:

- 공유기 포트포워딩이 거의 필요 없다.
- 프록시를 인터넷에 직접 공개하지 않아도 된다.
- 개인용 운영에 안전하고 관리가 쉽다.

### HTTPS reverse proxy

도메인이 있고 외부 공개가 필요하다면 Caddy 또는 Nginx로 HTTPS reverse proxy를 구성한다.

Caddy 예시:

```caddyfile
fitface-proxy.example.com {
    reverse_proxy 127.0.0.1:8787
}
```

앱 설정:

```text
https://fitface-proxy.example.com
```

주의: 현재 프록시는 별도 인증 토큰이 없으므로, 이 방식으로 인터넷에 공개하기 전에는 인증 토큰 기능을 추가하는 것이 안전하다.

## 방화벽

LAN에서만 쓸 경우:

- NAS/서버 방화벽에서 TCP `8787` 허용
- 공유기 포트포워딩 불필요
- 앱 주소는 `http://NAS_IP:8787`

외부에서 쓸 경우:

- Tailscale/WireGuard 사용 시 공유기 포트포워딩 불필요
- HTTPS reverse proxy 사용 시 공유기에서 `80`, `443`만 reverse proxy 서버로 포워딩
- `8787`을 인터넷에 직접 열지 않는 것을 권장

## 배포 후 점검

서버 내부:

```bash
curl http://127.0.0.1:8787/health
```

같은 Wi-Fi의 다른 장치:

```bash
curl http://NAS_IP:8787/health
```

응답:

```json
{"ok":true}
```

프록시 로그:

```bash
docker compose logs -f fitface-openai-proxy
```

또는 systemd:

```bash
journalctl -u fitface-openai-proxy -f
```

앱 연결 테스트:

```text
설정 -> OpenAI 프록시 주소 -> 연결 테스트
```

성공 메시지:

```text
OpenAI 프록시 연결이 확인되었습니다.
```

## 장애 대응

### 앱 연결 테스트 실패

확인할 것:

- 프록시 서버가 실행 중인지
- `curl http://서버IP:8787/health`가 성공하는지
- `FITFACE_PROXY_HOST=0.0.0.0`인지
- NAS/서버 방화벽에서 TCP `8787`이 열려 있는지
- Windows PC에서 실행 중이면 Windows Defender Firewall에서 TCP `8787` 인바운드가 허용되어 있는지
- 휴대폰과 서버가 같은 네트워크 또는 VPN에 있는지
- 앱에 `127.0.0.1`이 아니라 서버 IP를 넣었는지

잘못된 예:

```text
http://127.0.0.1:8787
```

휴대폰에서 `127.0.0.1`은 휴대폰 자기 자신을 의미한다. PC/NAS 프록시에 연결되지 않는다.

올바른 예:

```text
http://192.168.0.20:8787
```

Windows PC에서 서버 IP 확인:

```powershell
ipconfig
```

`IPv4 Address` 또는 `IPv4 주소` 항목의 사설 IP를 앱에 넣는다.

서버가 실제로 포트를 열었는지 확인:

```powershell
Get-NetTCPConnection -LocalPort 8787 -State Listen
```

### 프록시 시작 실패

확인할 것:

- `OPENAI_API_KEY`가 설정되어 있는지
- 포트 `8787`을 이미 다른 프로세스가 쓰는지
- Docker container 로그 또는 systemd 로그에 오류가 있는지

#### `MISSING_OPENAI_API_KEY: OPENAI_API_KEY is required.`

원인:

```text
OPENAI_API_KEY가 현재 실행 프로세스의 환경변수로 들어가지 않았다.
```

자주 발생하는 경우:

- `.env` 또는 `.env.local` 파일만 만들고 `dart run bin/fitface_openai_proxy.dart`를 바로 실행한 경우
- PowerShell을 새로 열었는데 환경변수를 다시 로딩하지 않은 경우
- systemd 서비스 파일에 `EnvironmentFile` 경로가 빠졌거나 파일 권한/경로가 틀린 경우

PowerShell 임시 해결:

```powershell
$env:OPENAI_API_KEY="sk-..."
$env:OPENAI_MODEL="gpt-5.4-mini"
$env:FITFACE_PROXY_HOST="0.0.0.0"
$env:FITFACE_PROXY_PORT="8787"

dart run bin/fitface_openai_proxy.dart
```

Bash 임시 해결:

```bash
export OPENAI_API_KEY="sk-..."
export OPENAI_MODEL="gpt-5.4-mini"
export FITFACE_PROXY_HOST="0.0.0.0"
export FITFACE_PROXY_PORT="8787"

dart run bin/fitface_openai_proxy.dart
```

systemd 확인:

```bash
sudo systemctl cat fitface-openai-proxy
sudo ls -l /etc/fitface-openai-proxy.env
sudo systemctl restart fitface-openai-proxy
journalctl -u fitface-openai-proxy -n 100 --no-pager
```

#### `SocketException: Failed host lookup: '"0.0.0.0"'`

원인:

```text
FITFACE_PROXY_HOST 값에 따옴표가 문자 그대로 포함되어 있다.
```

정상 값:

```text
0.0.0.0
```

잘못된 값:

```text
"0.0.0.0"
```

PowerShell에서 현재 값 확인:

```powershell
Write-Output "<$env:FITFACE_PROXY_HOST>"
```

`<"0.0.0.0">`처럼 보이면 잘못 들어간 것이다. 다시 설정한다.

```powershell
$env:FITFACE_PROXY_HOST="0.0.0.0"
$env:FITFACE_PROXY_PORT="8787"
dart run bin/fitface_openai_proxy.dart
```

Bash에서 현재 값 확인:

```bash
printf '<%s>\n' "$FITFACE_PROXY_HOST"
```

`<"0.0.0.0">`처럼 보이면 환경변수 파일에서 따옴표를 제거한다.

포트 확인:

```bash
sudo ss -ltnp | grep 8787
```

Windows 포트 확인:

```powershell
Get-NetTCPConnection -LocalPort 8787 -State Listen | Select-Object LocalAddress,LocalPort,OwningProcess
$targetPid = 12345
Get-CimInstance Win32_Process -Filter "ProcessId=$targetPid" | Select-Object ProcessId,Name,CommandLine
```

`12345`는 위 명령에서 확인한 `OwningProcess` 값으로 바꾼다. 해당 PID가 FitFace 프록시 서버가 맞을 때만 종료한다.

```powershell
Stop-Process -Id $targetPid
```

### OpenAI 요청 실패

확인할 것:

- API key가 유효한지
- OpenAI account billing/usage limit 상태
- 서버에서 외부 HTTPS 통신이 가능한지
- 프록시 로그에 `OPENAI_REQUEST_FAILED`가 찍히는지

## 업데이트

Docker Compose 방식:

```bash
cd fitface
git pull
docker compose up -d --build
```

systemd 방식:

```bash
cd /opt/fitface
sudo -u fitface git pull
sudo -u fitface dart pub get
sudo systemctl restart fitface-openai-proxy
```

상태 확인:

```bash
curl http://127.0.0.1:8787/health
```

## 참고 링크

- Dart SDK 설치 공식 문서: https://dart.dev/get-dart
- Dart Docker 공식 이미지: https://hub.docker.com/_/dart
- FitFace repository: https://github.com/kjs3047/fitface
