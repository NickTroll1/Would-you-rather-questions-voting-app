DOCKER_USER ?= nikolasmin
APP_NAME    := would-you-rather
VERSION     ?= 0.1.0
IMAGE       := $(DOCKER_USER)/$(APP_NAME):$(VERSION)

.PHONY: help test build push deploy status logs rollback clean

help:
	@echo "Targets:"
	@echo "  test      Run pytest locally before any build."
	@echo "  build     Build the Docker image as $(IMAGE)."
	@echo "  push      Push the image to Docker Hub."
	@echo "  deploy    Apply all Kubernetes manifests."
	@echo "  status    Show Deployments, Pods, and Services."
	@echo "  logs      Tail logs from all app replicas."
	@echo "  rollback  Roll back to the previous app revision."
	@echo "  clean     Delete all deployed resources."
	@echo ""
	@echo "Variables: DOCKER_USER=<dockerhub-user> VERSION=<tag>"

test:
	python -m pytest -q

build:
	docker build -t $(IMAGE) .

push:
	docker push $(IMAGE)

deploy:
	kubectl apply -f k8s/01-configmap.yaml
	kubectl apply -f k8s/02-secret.yaml
	kubectl apply -f k8s/03-pvc.yaml
	kubectl apply -f k8s/04-deployment-db.yaml
	kubectl apply -f k8s/05-service-db.yaml
	@echo "Waiting for PostgreSQL to be ready..."
	kubectl rollout status deployment/postgres --timeout=120s
	sed "s|REPLACE_ME_USER/would-you-rather:0.1.0|$(IMAGE)|g" k8s/06-deployment-app.yaml | kubectl apply -f -
	kubectl apply -f k8s/07-service-app.yaml
	kubectl rollout status deployment/voting-app --timeout=180s
	@echo "Use: kubectl port-forward svc/voting-app 8080:80"

status:
	kubectl get deployments
	kubectl get pods -o wide
	kubectl get services
	kubectl get pvc

logs:
	kubectl logs -l app=voting-app --tail=100 --prefix

rollback:
	kubectl rollout undo deployment/voting-app
	kubectl rollout status deployment/voting-app --timeout=180s

clean:
	kubectl delete -f k8s/07-service-app.yaml --ignore-not-found
	kubectl delete -f k8s/06-deployment-app.yaml --ignore-not-found
	kubectl delete -f k8s/05-service-db.yaml --ignore-not-found
	kubectl delete -f k8s/04-deployment-db.yaml --ignore-not-found
	kubectl delete -f k8s/03-pvc.yaml --ignore-not-found
	kubectl delete -f k8s/02-secret.yaml --ignore-not-found
	kubectl delete -f k8s/01-configmap.yaml --ignore-not-found
