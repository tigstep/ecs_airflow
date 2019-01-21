[
    {
        "name": "webserver",
        "image": "puckel/docker-airflow",
        "essential": true,
        "environment": [
            {
                "name": "LOAD_EX",
                "value": "n"
            },
            {
                "name": "FERNET_KEY",
                "value": "${fernet_key}"
            },
            {
                "name": "EXECUTOR",
                "value": "Celery"
            },
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
            },
            {
                "name": "POSTGRES_HOST",
                "value": "${postgres_host}"
            },
            {
                "name": "REDIS_HOST",
                "value": "${redis_host}"
            }
        ],
        "portMappings": [{
            "containerPort": 8080,
            "hostPort": 8080
        }],
        "mountPoints": [
            {
                "sourceVolume": "dag_folder",
                "containerPath": "/usr/local/airflow/dags"
            }
        ],
        "memory": 512,
        "cpu": 256,
        "command": ["webserver"]
    },
    {
        "name": "flower",
        "image": "puckel/docker-airflow",
        "essential": false,
        "environment": [{
            "name": "EXECUTOR",
            "value": "Celery"
        }],
        "portMappings": [{
            "containerPort": 5555,
            "hostPort": 5555
        }],
        "memory": 128,
        "cpu": 128,
        "command": ["flower"]
    },
    {
        "name": "scheduler",
        "image": "puckel/docker-airflow",
        "essential": true,
        "depends_on": [
            "webserver"
        ],
        "environment": [{
                "name": "LOAD_EX",
                "value": "n"
            },
            {
                "name": "FERNET_KEY",
                "value": "${fernet_key}"
            },
            {
                "name": "EXECUTOR",
                "value": "Celery"
            },
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
            },
            {
                "name": "POSTGRES_HOST",
                "value": "${postgres_host}"
            },
            {
                "name": "REDIS_HOST",
                "value": "${redis_host}"
            }
        ],
        "mountPoints": [
            {
                "sourceVolume": "dag_folder",
                "containerPath": "/usr/local/airflow/dags"
            }
        ],
        "memory": 128,
        "cpu": 128,
        "command": ["scheduler"]
    },
    {
        "name": "worker",
        "image": "puckel/docker-airflow",
        "essential": true,
        "depends_on": [
            "scheduler"
        ],
        "environment": [{
                "name": "LOAD_EX",
                "value": "n"
            },
            {
                "name": "FERNET_KEY",
                "value": "${fernet_key}"
            },
            {
                "name": "EXECUTOR",
                "value": "Celery"
            },
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
            },
            {
                "name": "POSTGRES_HOST",
                "value": "${postgres_host}"
            },
            {
                "name": "REDIS_HOST",
                "value": "${redis_host}"
            }
        ],
        "mountPoints": [
            {
                "sourceVolume": "dag_folder",
                "containerPath": "/usr/local/airflow/dags"
            }
        ],
        "memory": 1024,
        "cpu": 256,
        "command": ["worker"]
    }
]