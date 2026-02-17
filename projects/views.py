from django.shortcuts import render
from django.http import HttpResponse


def getProjects(request):
    return render(request, 'projects/projects.html')

def getProject(request, id):
    return render(request, 'projects/single-project.html')
