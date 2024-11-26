FROM python:3.6-slim

# Actualizar los paquetes e instalar dependencias
RUN apt-get update && apt-get install -y \
    openjdk-17-jre \
    git \
    make \
    && apt-get clean

# Crear el directorio de trabajo
RUN mkdir -p /opt/calc

# Establecer el directorio de trabajo
WORKDIR /opt/calc

# Copiar los archivos necesarios
COPY .coveragerc .pylintrc pyproject.toml pytest.ini requires ./
COPY app ./app
COPY test ./test

# Instalar las dependencias de Python
RUN pip install -r requires
