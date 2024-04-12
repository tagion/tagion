import subprocess
import pytest

RES_DIR="../res"

def test_dartutil_execution():
    command = ["dartutil", f"{RES_DIR}/sample.drt", "--eye"]
    result = subprocess.run(command, capture_output=True, text=True, check=True)

    with open(f"{RES_DIR}/sample_eye.txt", 'r') as file:
        expected_output = file.read().strip()

    assert result.stdout.strip() == expected_output