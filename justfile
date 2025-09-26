#!/usr/bin/env just --justfile
#705098187465.dkr.ecr.us-east-2.amazonaws.com/packages

set shell := ["bash", "-c"]
set dotenv-load := true

host_ssh := env_var("DOCKER_HOST_SSH")
version := `cat VERSION`
bold_font := `tput bold`
normal_font := `tput sgr0`

# List all available recipes
_list:
    @just --list

# Attach code to PHP runtime image and push to Heroku registry
@build target_env='dev':
    echo "Building version {{ version }} for {{ target_env }}"
    if [ {{ target_env }} = 'local' ] || [ {{ target_env }} = 'dev' ]; then \
        echo "Build unnecessary for {{ target_env }}"; \
    elif [ {{ target_env }} = 'production' ]; then \
            echo "{{ bold_font }}=== Building packages app (${PWD}/Dockerfile){{ normal_font }}"; \
            docker buildx build --pull \
                --platform linux/amd64,linux/arm64 \
                -f Dockerfile \
                --build-arg APP_VER={{ version }} \
                 -t 705098187465.dkr.ecr.us-east-2.amazonaws.com/packages:latest \
                 -t 705098187465.dkr.ecr.us-east-2.amazonaws.com/packages:{{ version }} \
                 --push \
                 .; \
            docker system prune -f; \
            docker images | grep -E "705098187465.dkr.ecr.us-east-2.amazonaws.com\/packages"; \
    else \
        echo "Unknown environment: {{ target_env }}"; \
    fi

@install target_env='dev':
    echo "Installing version {{ version }} for {{ target_env }}"
    if [ {{ target_env }} = 'local' ] || [ {{ target_env }} = 'dev' ]; then \
        echo "Install unnecessary for {{ target_env }}"; \
    elif [ {{ target_env }} = 'production' ]; then \
        ssh {{ host_ssh }} 'mkdir -p /var/docker/packages/'; \
        scp ./docker-compose.yml ./start.sh ./pull.sh {{ host_ssh }}:/var/docker/packages/; \
        scp ./.env.production {{ host_ssh }}:/var/docker/packages/.env; \
        ssh {{ host_ssh }} 'chmod +x /var/docker/packages/*.sh; cd /var/docker/packages; ./pull.sh'; \
    fi

# Deploy (start) code to the target environment
@deploy target_env='dev':
    echo "Deploying version {{ version }} to {{ target_env }}"
    if [ {{ target_env }} = 'dev' ]; then \
        docker compose -f docker-compose-dev.yml  up -d; \
    elif [ {{ target_env }} = 'production' ]; then \
        ssh {{ host_ssh }} 'cd /var/docker/packages; docker compose up -d'; \
    else \
        echo "Unknown environment: {{ target_env }}"; \
    fi

# Status of the target environment
@status target_env='dev':
    echo "Status on {{ target_env }}"
    if [ {{ target_env }} = 'dev' ]; then \
        docker compose -f docker-compose-dev.yml ps; \
    elif [ {{ target_env }} = 'production' ]; then \
        ssh {{ host_ssh }} 'cd /var/docker/packages; docker compose ps'; \
    else \
        echo "Unknown environment: {{ target_env }}"; \
    fi

# Logs of the target environment
@logs target_env='dev' follow='':
    echo "Logs on {{ target_env }} {{ follow }}"
    if [ {{ target_env }} = 'dev' ]; then \
        if [ "{{ follow }}" = 'follow' ]; then \
            docker compose -f docker-compose-dev.yml logs -f; \
        else \
            docker compose -f docker-compose-dev.yml logs; \
        fi \
    elif [ {{ target_env }} = 'production' ]; then \
        if [ "{{ follow }}" = 'follow' ]; then \
            ssh {{ host_ssh }} 'cd /var/docker/packages; docker compose logs -f'; \
        else \
            ssh {{ host_ssh }} 'cd /var/docker/packages; docker compose logs'; \
        fi \
    else \
        echo "Unknown environment: {{ target_env }}"; \
    fi

# Shut down target environment
@down target_env='dev':
    echo "Shutting down on {{ target_env }}"
    if [ {{ target_env }} = 'dev' ]; then \
        docker compose -f docker-compose-dev.yml down; \
    elif [ {{ target_env }} = 'production' ]; then \
        ssh {{ host_ssh }} 'cd /var/docker/packages; docker compose down'; \
    else \
        echo "Unknown environment: {{ target_env }}"; \
    fi

# Reboot (down + deploy) services in target environment
@reboot target_env='dev':
    echo "Restarting services on {{ target_env }}"
    if [ {{ target_env }} = 'dev' ] || [ {{ target_env }} = 'production' ]; then \
        just down {{ target_env }}; \
        just deploy {{ target_env }}; \
    else \
        echo "Unknown environment: {{ target_env }}"; \
    fi

# Start bash in a remote container in the specified environment
@exec target_env='dev' target_process='releasebelt':
    echo "Connecting to {{ target_process }} container on {{ target_env }}"
    if [ {{ target_env }} = 'dev' ]; then \
        docker compose -f docker-compose-dev.yml exec {{ target_process }} bash; \
    elif [ {{ target_env }} = 'production' ]; then \
        ssh {{ host_ssh }} 'cd /var/docker/packages; docker compose exec {{ target_process }} bash'; \
    else \
        echo "Unknown environment: {{ target_env }}"; \
    fi

# Show or increment (major, minor, patch) the release version
@version action='show':
    if [ {{ action }} = 'major' ]; then \
        docker run --rm -v "$PWD":/app perteghella/bump major; echo; \
    elif [ {{ action }} = 'minor' ]; then \
        docker run --rm -v "$PWD":/app perteghella/bump minor; echo; \
    elif [ {{ action }} = 'patch' ]; then \
        docker run --rm -v "$PWD":/app perteghella/bump patch; echo; \
    else \
        cat VERSION; \
    fi

# Retrieve an authentication token for the AWS registry
@auth:
    echo "Obtaining authentication token for AWS ECR container registry"; \
    aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 705098187465.dkr.ecr.us-east-2.amazonaws.com
