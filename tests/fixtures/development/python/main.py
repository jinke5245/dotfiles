import sys

assert sys.prefix != sys.base_prefix, "Expected a project virtual environment"
print("python:ok")
