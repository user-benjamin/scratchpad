import boto3

def get_parameter(name):
    """Fetch a single parameter from AWS SSM Parameter Store."""
    ssm = boto3.client('ssm')
    response = ssm.get_parameter(Name=name, WithDecryption=True)
    return response['Parameter']['Value']

if __name__ == "__main__":
    param_name = input("Enter parameter name: ")
    value = get_parameter(param_name)
    print(f"Value: {value}")
