from django.shortcuts import render

from django.http import HttpResponse

def getHomePage(request):
    return HttpResponse("Hello World")

def getProject(request, id):
    return HttpResponse(f"Hello Proejct {id}")
