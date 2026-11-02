@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo === CrediSol: subir a GitHub (credi_sol_terminada) ===

echo Borrando archivos obsoletos (tienda y rastreo GPS)...
del /q lib\tienda_screen.dart lib\carrito_screen.dart lib\admin_tienda_screen.dart lib\catalogo_ejemplo.dart lib\tienda_modelos.dart lib\config_tienda.dart lib\splash_screen.dart lib\ubicacion_gate.dart test\tienda_test.dart docs\tienda.md 2>nul

if not exist .git (
  git init
)
git add .
git commit -m "CrediSol: 40 creditos con imagen 3D, login 3D, score, mapas sin rastreo, validacion con IA y APIs DNI/RUC"
git branch -M proyecto_block
git remote remove origin 2>nul
git remote add origin https://github.com/jeanpachecogaspar-oss/credi_sol_terminada.git
git push -u origin proyecto_block

echo.
echo === Listo. Revisa: https://github.com/jeanpachecogaspar-oss/credi_sol_terminada ===
pause
