[
  {
    "name": "webserver",
    "links": [
      "postgres"
    ],
    "image": "puckel/docker-airflow",
    "essential": true,
    "environment": [
      {
        "name": "LOAD_EX",
        "value": "n"
      }
    ],
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
      }
    ],
    "mountPoints": [
      {
        "sourceVolume": "dag_folder",
        "containerPath": "/usr/local/airflow/dags"
      }
    ],
    "memory": 400,
    "cpu": 7
  },
  {
    "name": "postgres",
    "image": "postgres",
    "environment": [
      {
        "name": "POSTGRES_USER",
        "value": "${postgres_user}"
      },
      {
        "name": "POSTGRES_PASSWORD",
        "value": "${postgres_password}"
      },
      {
        "name": "POSTGRES_DB",
        "value": "${postgres_db}"
      }
    ],
    "memory": 400,
    "cpu": 7
  }
]