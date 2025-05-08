@echo off
REM Navegar a la carpeta lib del proyecto Flutter
cd lib

REM Crear las carpetas principales
mkdir common
mkdir data
mkdir presentation
mkdir services
mkdir routing

REM Crear subcarpetas dentro de common
cd common
mkdir widgets
mkdir utils
mkdir theme
cd ..

REM Crear subcarpetas dentro de data
cd data
mkdir data_sources
mkdir models
mkdir repositories
cd data_sources
mkdir local
mkdir remote
cd ..\..

REM Crear subcarpetas dentro de presentation
cd presentation
mkdir screens
mkdir widgets
mkdir blocs
mkdir providers
mkdir riverpod
mkdir state
cd blocs
mkdir tracking
mkdir user
cd ..\..

REM Crear subcarpeta dentro de routing
cd routing
mkdir app_router
cd ..

echo Estructura de carpetas creada exitosamente en lib/
pause