#!/bin/bash

# Prompt for project name
read -p "Enter your project name: " project_name

# Create Vite project with React template
npm create vite@latest "$project_name" -- --template react 

# Navigate to project directory
cd "$project_name"

# Install dependencies
npm install

# Navigate back to parent directory
cd ..

# Open project in VS Code
code "$project_name"

explorer.exe http://localhost:5173

# Navigate back to project folder and run dev server
cd "$project_name" 
npm run dev 
