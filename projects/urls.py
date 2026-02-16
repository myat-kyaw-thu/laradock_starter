from django.urls import path
from .import views
urlpatterns = [
    path("", views.getHomePage , name='homePage'),
    path('project/<str:id>', views.getProject, name="proejctDetail")
]
