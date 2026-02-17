from django.urls import path

from .import views
urlpatterns = [
    path("", views.getProjects , name='projects'),
    path('project/<str:id>', views.getProject, name="projectDetail")
]
