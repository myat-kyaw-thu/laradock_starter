from django.shortcuts import render
from django.http import HttpResponse


def getProjects(request):
    projects = [
        {'id': 1, 'name': 'E-commerce Website', 'description': 'Online shopping platform'},
        {'id': 2, 'name': 'Blog System', 'description': 'Content management system'},
        {'id': 3, 'name': 'Task Manager', 'description': 'Project tracking tool'},
    ]
    return render(request, 'projects/projects.html', {'projects': projects})

def getProject(request, id):
    projects = {
        '1': {'id': 1, 'name': 'E-commerce Website', 'description': 'Online shopping platform'},
        '2': {'id': 2, 'name': 'Blog System', 'description': 'Content management system'},
        '3': {'id': 3, 'name': 'Task Manager', 'description': 'Project tracking tool'},
    }
    project = projects.get(id, {'id': id, 'name': 'Not Found', 'description': 'Project does not exist'})
    return render(request, 'projects/single-project.html', {'project': project})
