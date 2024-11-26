.PHONY: all $(MAKECMDGOALS)

build:
	docker build -t calculator-app .
	docker build -t calc-web ./web

server:
	docker run --rm --name apiserver --network-alias apiserver \
		--env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py \
		-p 5000:5000 -w /opt/calc calculator-app:latest \
		flask run --host=0.0.0.0

test-unit:
	-docker run --name unit-tests --env PYTHONPATH=/opt/calc \
		-w /opt/calc calculator-app:latest \
		pytest --cov --cov-report=xml:results/coverage.xml \
		--cov-report=html:results/coverage \
		--junit-xml=results/unit_result.xml -m unit
	docker cp unit-tests:/opt/calc/results ./
	-docker rm unit-tests

test-api:
# Verifica si la red ya existe antes de intentar crearla
	@docker network ls --filter "name=calc-test-api" --format "{{.Name}}" | \
		findstr calc-test-api >nul || ( \
			docker network create calc-test-api && \
			echo "Network calc-test-api created." \
		)
	docker run -d --network calc-test-api --env PYTHONPATH=/opt/calc \
		--name apiserver --env FLASK_APP=app/api.py -p 5000:5000 \
		-w /opt/calc calculator-app:latest \
		flask run --host=0.0.0.0
	-docker run --network calc-test-api --name api-tests \
		--env PYTHONPATH=/opt/calc --env BASE_URL=http://apiserver:5000/ \
		-w /opt/calc calculator-app:latest \
		pytest --junit-xml=results/api_result.xml -m api
	docker cp api-tests:/opt/calc/results ./
	-docker stop apiserver
	-docker rm --force apiserver
	-docker stop api-tests
	-docker rm --force api-tests
	-docker network rm calc-test-api

test-e2e:
# Verifica si la red ya existe antes de intentar crearla
	@docker network ls --filter "name=calc-test-e2e" --format "{{.Name}}" | \
		findstr calc-test-e2e >nul || ( \
			docker network create calc-test-e2e && \
			echo "Network calc-test-e2e created." \
		)
# Verifica si los contenedores existen antes de detenerlos o eliminarlos
	@docker ps -q --filter "name=apiserver" | findstr . >nul && \
		docker stop apiserver || echo "No container named apiserver to stop"
	@docker ps -a -q --filter "name=apiserver" | findstr . >nul && \
		docker rm --force apiserver || echo "No container named apiserver to remove"
	@docker ps -q --filter "name=calc-web" | findstr . >nul && \
		docker stop calc-web || echo "No container named calc-web to stop"
	@docker ps -a -q --filter "name=calc-web" | findstr . >nul && \
		docker rm --force calc-web || echo "No container named calc-web to remove"
	@docker ps -q --filter "name=e2e-tests" | findstr . >nul && \
		docker stop e2e-tests || echo "No container named e2e-tests to stop"
	@docker ps -a -q --filter "name=e2e-tests" | findstr . >nul && \
		docker rm --force e2e-tests || echo "No container named e2e-tests to remove"
# Ejecuta los contenedores necesarios para las pruebas
	docker run -d --network calc-test-e2e --env PYTHONPATH=/opt/calc \
		--name apiserver --env FLASK_APP=app/api.py -p 5000:5000 \
		-w /opt/calc calculator-app:latest \
		flask run --host=0.0.0.0
	docker run -d --network calc-test-e2e --name calc-web -p 80:80 calc-web
# Crea y ejecuta las pruebas E2E
	docker create --network calc-test-e2e --name e2e-tests \
		cypress/included:4.9.0 --browser chrome
	docker cp ./test/e2e/cypress.json e2e-tests:/cypress.json
	docker cp ./test/e2e/cypress e2e-tests:/cypress
	-docker start -a e2e-tests || echo "E2E tests execution finished with some errors"
# Copia los resultados de las pruebas
	-docker cp e2e-tests:/results ./ || echo "No results to copy from e2e-tests"
# Limpia los contenedores y la red
	-docker ps -a -q --filter "name=apiserver" | findstr . >nul && \
		docker rm --force apiserver || echo "No container named apiserver to remove"
	-docker ps -a -q --filter "name=calc-web" | findstr . >nul && \
		docker rm --force calc-web || echo "No container named calc-web to remove"
	-docker ps -a -q --filter "name=e2e-tests" | findstr . >nul && \
		docker rm --force e2e-tests || echo "No container named e2e-tests to remove"
	-docker network ls --filter "name=calc-test-e2e" --format "{{.Name}}" | \
		findstr calc-test-e2e >nul && docker network rm calc-test-e2e || \
		echo "No network named calc-test-e2e to remove"

run-web:
	docker run --rm --volume $(CURDIR)/web:/usr/share/nginx/html \
		--volume $(CURDIR)/web/constants.local.js:/usr/share/nginx/html/constants.js \
		--name calc-web -p 80:80 nginx

stop-web:
	docker stop calc-web

start-sonar-server:
# Verifica si la red ya existe antes de intentar crearla
	@docker network ls --filter "name=calc-sonar" --format "{{.Name}}" | \
		findstr calc-sonar >nul || ( \
			docker network create calc-sonar && \
			echo "Network calc-sonar created." \
		)
	docker run -d --rm --stop-timeout 60 --network calc-sonar \
		--name sonarqube-server -p 9000:9000 \
		--volume $(CURDIR)/sonar/data:/opt/sonarqube/data \
		--volume $(CURDIR)/sonar/logs:/opt/sonarqube/logs \
		sonarqube:8.3.1-community

stop-sonar-server:
	docker stop sonarqube-server
	-docker network rm calc-sonar

start-sonar-scanner:
	docker run --rm --network calc-sonar -v $(CURDIR):/usr/src \
		sonarsource/sonar-scanner-cli

pylint:
	docker run --rm --volume $(CURDIR):/opt/calc --env PYTHONPATH=/opt/calc \
		-w /opt/calc calculator-app:latest pylint app/ | \
		tee results/pylint_result.txt

deploy-stage:
	-docker stop apiserver
	-docker stop calc-web
	docker run -d --rm --name apiserver --network-alias apiserver \
		--env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py \
		-p 5000:5000 -w /opt/calc calculator-app:latest \
		flask run --host=0.0.0.0
	docker run -d --rm --name calc-web -p 80:80 calc-web
