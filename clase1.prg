
'=======================
' CURSO EVIEWS - CLASE 1
' Ejecutar por bloques: seleccionar lineas + clic derecho > Run Selected
'======================



'---------------------------------------------------------------------
' BLOQUE 0. Directorio de trabajo
'---------------------------------------------------------------------
cd "C:\Users\aalvarado\OneDrive - International Monetary Fund (PRD)\Personal\training_eviews_bcrp"

close @objects                    ' cierra ventanas abiertas

'---------------------------------------------------------------------
' BLOQUE 1. Workfile, muestra y funciones generadoras
'---------------------------------------------------------------------

wfcreate(wf=anual) a 1990 2024        ' anual
wfcreate(wf=mensual) m 2000m1 2003m12 ' mensual: observar el rango
wfselect anual                        ' volver al workfile anual

series t = @trend                 ' 0,1,2,...
series n = @obsnum                ' 1,2,3,...
series e = @nrnd                  ' N(0,1)
series u = @rnd                   ' U(0,1)
series y = 1 + 0.02*t + e         ' tendencia + ruido
series yd = y - @mean(y)          ' desvio respecto de la media

' smpl: comparar la media de y en cada muestra
smpl @all
scalar m_all = @mean(y)
smpl 2000 2019
scalar m_0019 = @mean(y)
smpl @first 2007
scalar m_first = @mean(y)
smpl if y > 1
scalar m_if = @mean(y)
smpl @all                         ' siempre volver a la muestra completa

pagecontract 2000 2019            ' reduce el rango del workfile (irreversible)

'---------------------------------------------------------------------
' BLOQUE 2. Importacion de datos (Fiji, anual 1970-2013)
'---------------------------------------------------------------------
import "Fiji.xlsx" range=Fiji colhead=1 na="#N/A" @id @date(date) @smpl @all
' Ver: frecuencia (anual) y rango del workfile en la ventana
'import con un workfile abierto ajusta los datos al rango existente Si se corre de corrido, se omite 1970 al 2000.

close @objects
smpl @all

'---------------------------------------------------------------------
' BLOQUE 3. genr vs. expresiones y transformaciones
'---------------------------------------------------------------------
' genr: crea y guarda la serie (aparece en el workfile)
genr ln_rgdp_fiji = log(rgdp_fiji)
genr ln_rgdp_aus  = log(rgdp_aus)

' Expresion: mismo resultado, sin crear objetos
line ln_rgdp_fiji
line log(rgdp_fiji)






' Transformaciones utiles (datos anuales)
series d_fiji    = d(rgdp_fiji)          ' primera diferencia
series dl_fiji   = dlog(rgdp_fiji)*100       ' crecimiento (aprox.)
series pc_fiji   = @pc(rgdp_fiji)        ' variacion % exacta
series lag_fiji  = rgdp_fiji(-3)         ' rezago de 1 periodo
series ma_fiji   = @movav(rgdp_fiji,3)   ' media movil de 3 anios
series dum2000   = (@year>=2000)         ' dummy desde 2000
series exp_check = exp(ln_rgdp_fiji)     ' vuelve al nivel


line dlog(rgdp_fiji) dlog(rgdp_aus)


'---------------------------------------------------------------------
' BLOQUE 4. Graficos (inspeccion preliminar)
'---------------------------------------------------------------------
line ln_rgdp_fiji ln_rgdp_aus            ' niveles (log)
line(m) dlog(rgdp_fiji) dlog(rgdp_aus)   ' (m): un panel por serie
line dlog(rgdp_fiji) dlog(rgdp_aus)      ' mismo eje: Fiji mas volatil

scat log(rgdp_aus) log(rgdp_fiji)        ' niveles: relacion casi lineal
scat dlog(rgdp_aus) dlog(rgdp_fiji)      ' crecimientos: relacion debil

graph gr_niveles.line ln_rgdp_fiji ln_rgdp_aus   ' grafico guardado como objeto


'---------------------------------------------------------------------
' BLOQUE 5. Grupos y estadisticas
'---------------------------------------------------------------------
group g1 dlog(rgdp_fiji) dlog(rgdp_aus)
g1.stats                          ' muestra comun
g1.cov                            ' matriz de covarianzas
g1.corr                           ' matriz de correlaciones

' Muestra comun vs. individual: serie con faltantes
group g2 sugaroutput_fiji sugaroutput_fiji_missing
g2.stats                          ' comun: mismas observaciones
g2.stats(i)                       ' individual: comparar fila Observations




'---------------------------------------------------------------------
' BLOQUE 6. Objeto ecuacion: OLS
'---------------------------------------------------------------------

equation e1.ls ln_rgdp_fiji c ln_rgdp_aus          ' con series creadas (genr)
equation e2.ls log(rgdp_fiji) c log(rgdp_aus)      ' con expresiones: mismo resultado
' Log-log: c(2) = elasticidad

equation e3.ls dlog(rgdp_fiji) c dlog(rgdp_aus)    ' en crecimientos
equation e4.ls dlog(rgdp_fiji) c dlog(rgdp_aus) dlog(rgdp_fiji(-1)) dum2000   ' rezago + dummy
series dl_aus = dlog(rgdp_aus)
equation e5.ls dlog(rgdp_fiji) c dl_aus(0 to -2)  ' lista de rezagos

' Muestra restringida
smpl 1970 1999
equation e6.ls dlog(rgdp_fiji) c dlog(rgdp_aus)
smpl @all

' Extraer resultados del objeto ecuacion
scalar elast  = e2.@coefs(2)
scalar r2_e2  = e2.@r2
scalar ssr_e2 = e2.@ssr

' Guardar
wfsave fiji_clase1

'-----------------------------------
' BLOQUE 7 (OPCIONAL). Datos trimestrales: @seas, @pcy, @movav
'-----------------------------------
wfopen(type=excelxml) "cri.xlsx" range="Sheet3!B2:F94" colhead=1
pagestruct(freq=q, start=2005q1)

line @pcy(gdp) @movav(@pcy(gdp),4)        ' var. interanual y media movil 4 trim.
equation eq_q.ls dlog(gdp) c @seas(1) @seas(2) @seas(3)   ' dummies estacionales


