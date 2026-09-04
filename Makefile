.PHONY: install ingest test schema

install:
	pip install -r requirements.txt

ingest:
	python -m ingestion.pull_gamelogs

schema:
	psql -f sql/schema/001_create_tables.sql
	psql -f sql/schema/002_indexes.sql

test:
	pytest
