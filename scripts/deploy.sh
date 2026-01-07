#!/bin/bash
# scripts/deploy.sh

APP_NAME="hello-spring" # appspec.yml의 프로젝트 이름과 일치
LIFECYCLE_EVENT="$LIFECYCLE_EVENT" # CodeDeploy가 주입하는 환경 변수

DEPLOY_DIR="/home/ec2-user/deploy/$APP_NAME" # TODO: appspec.yml의 destination과 일치
FINAL_JAR_NAME="hello-spring-app.jar" # 최종적으로 EC2에서 사용할 JAR 파일 이름 (고정)
CURRENT_APP_PATH="$DEPLOY_DIR/$FINAL_JAR_NAME"
APP_PORT="8080"
SPRING_PROFILES_ACTIVE="prod"
LOG_FILE="$DEPLOY_DIR/nohup.out"

echo "#########################################################"
echo "# Start deploy.sh for event: $LIFECYCLE_EVENT"
echo "#########################################################"

case "$LIFECYCLE_EVENT" in

  ApplicationStop)
    echo "[$LIFECYCLE_EVENT] Hook executing..."

    # 'java -jar'를 포함하고 현재 애플리케이션 JAR 파일명과 일치하는 프로세스 종료
    PIDS_TO_KILL_JAVA=$(ps -ef | grep "java -jar $CURRENT_APP_PATH" | grep -v grep | awk '{print $2}')
    
    if [ -n "$PIDS_TO_KILL_JAVA" ]; then
        echo "Found Java JAR processes for $APP_NAME with PIDS: $PIDS_TO_KILL_JAVA. Attempting graceful termination (SIGTERM)..."
        echo "$PIDS_TO_KILL_JAVA" | xargs -r kill
        sleep 5 
    else
        echo "No specific Java JAR process found for $APP_NAME."
    fi

    # $APP_PORT (8080)을 사용 중인 모든 프로세스 강제 종료 시도
    PORT_LISTENING_PIDS=$(lsof -t -i :"$APP_PORT") 
    if [ -n "$PORT_LISTENING_PIDS" ]; then
        echo "Found processes listening on port $APP_PORT with PIDS: $PORT_LISTENING_PIDS. Forcibly killing them (SIGKILL)..."
        echo "$PORT_LISTENING_PIDS" | xargs -r kill -9
        sleep 5 
    else
        echo "No process found directly listening on port $APP_PORT."
    fi
    echo "[$LIFECYCLE_EVENT] Hook completed."
    ;;

  AfterInstall)
    echo "[$LIFECYCLE_EVENT] Hook executing..."

    # CodeDeploy가 복사한 JAR 파일을 고정된 이름으로 변경
    TRANSFER_SOURCE_PATH=$(find "$DEPLOY_DIR" -maxdepth 1 -name "hello-spring-*.jar" -print -quit) # 빌드된 JAR 파일의 실제 이름을 찾음
    
    if [ -z "$TRANSFER_SOURCE_PATH" ]; then
        echo "Error: No hello-spring JAR file found in $DEPLOY_DIR after transfer. Deployment aborted."
        exit 1
    fi
    
    echo "Moving $TRANSFER_SOURCE_PATH to $CURRENT_APP_PATH"
    mv "$TRANSFER_SOURCE_PATH" "$CURRENT_APP_PATH" 
    
    # 권한 설정 (appspec.yml에서도 설정하지만, 스크립트에서도 한 번 더 적용하여 확실하게 함)
    chown ec2-user:ec2-user "$CURRENT_APP_PATH" # TODO: EC2 사용자명과 그룹명에 맞게 변경
    chmod 755 "$CURRENT_APP_PATH" 
    echo "[$LIFECYCLE_EVENT] Hook completed."
    ;;

  ApplicationStart)
    echo "[$LIFECYCLE_EVENT] Hook executing..."

    echo "Starting new Spring Boot application: $CURRENT_APP_PATH"
    
    # Spring Boot 애플리케이션 백그라운드 실행
    sudo -u ec2-user nohup java -jar "$CURRENT_APP_PATH" --spring.profiles.active="$SPRING_PROFILES_ACTIVE" > "$LOG_FILE" 2>&1 &
    
    echo "[$LIFECYCLE_EVENT] Hook completed. Application should be starting..."
    ;;

  ValidateService)
    echo "[$LIFECYCLE_EVENT] Hook executing..."

    HEALTH_CHECK_URL="http://localhost:$APP_PORT/actuator/health" 
    MAX_RETRIES=15 
    RETRY_INTERVAL=10 
    
    echo "Checking application health at $HEALTH_CHECK_URL"

    for i in $(seq 1 $MAX_RETRIES); do
        echo "Attempt $i/$MAX_RETRIES: Checking service health..."
        HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" || echo "000") 
        
        if [ "$HTTP_CODE" -eq 200 ]; then
            echo "Application is healthy! HTTP Status Code: $HTTP_CODE"
            echo "[$LIFECYCLE_EVENT] Hook completed successfully."
            exit 0 
        else
            echo "Application not yet healthy. HTTP Status Code: $HTTP_CODE. Waiting $RETRY_INTERVAL seconds..."
            sleep $RETRY_INTERVAL
        fi
    done
    echo "Application failed health check after $MAX_RETRIES attempts."
    echo "[$LIFECYCLE_EVENT] Hook FAILED."
    exit 1 
    ;;
esac