#!/bin/bash
# aws sso login --profile #profileName#
# aws ecr --profile datasci-prod describe-repositories
# aws ecr --profile datasci-prod describe-images --repository-name #repoName# --output text

import boto3

# Create an ECR client with a specific region
ecr = boto3.client('ecr', region_name='us-east-1')

# Get a list of all ECR repositories
repos = ecr.describe_repositories()['repositories']

# Loop through each repository and list its images
for repo in repos:
    # Get the repository name
    repo_name = repo['repositoryName']
    
    # Get a list of all images in the repository
    images = ecr.describe_images(repositoryName=repo_name)['imageDetails']
    
    # Loop through each image and print its name, size, and upload date
    for image in images:
        # print('Repository: ' + repo_name)
        # print('Image name: ' + image['imageTags'][0])
        # print('Size: ' + str(image['imageSizeInBytes']) + ' bytes')
        # print('Upload date: ' + str(image['imagePushedAt']))
        print(f"{repo_name},{image['imageTags'][0]},{str(image['imageSizeInBytes'])}")
