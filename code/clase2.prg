cd "C:\Users\alfredo\training_eviews_bcrp"

'=====================================================================
' CLASE 2 
' Pipeline: raiz unitaria -> identificacion -> estimacion -> diagnostico
'           -> cointegracion -> pronostico -> escenario
' Datos: Fiji.xlsx (anual, 1970-2013)
' USO: ejecutar POR BLOQUES (seleccionar lineas -> clic derecho -> Run Selected)
'=====================================================================


'=====================================================================
' BLOQUE 0. APERTURA: WORKFILE, DATOS Y LOGARITMOS
'=====================================================================
close @objects                                  ' cierra ventanas abiertas

wfcreate(wf=clase2, page=fiji) a 1970 2013      ' workfile anual, pagina "fiji"
import "Fiji.xlsx" range=Fiji colhead=1 na="#N/A" @id @date(date) @smpl @all


series lrgdp_fiji = log(rgdp_fiji)              ' PIB real Fiji en logs
series lrgdp_aus  = log(rgdp_aus)               ' PIB real Australia en logs

group g_log lrgdp_fiji lrgdp_aus
g_log.line                                      ' primera mirada: ambas con tendencia









'=====================================================================
' BLOQUE 1. DEMOSTRACION UNIVARIADA CON SERIES SIMULADAS
'=====================================================================
' Pagina aparte (200 obs, sin fechas) para no mezclar con Fiji
if @pageexist("sim") then
  pagedelete sim
endif
pagecreate(page=sim) u 200
rndseed 2026                                    ' semilla: todos obtienen las mismas series

series e = nrnd                                 ' ruido blanco N(0,1)





' --- 1a. Cinco procesos basicos ---
series ar1    = e                               ' valor inicial
series arma11 = e
smpl @first+1 @last                             ' la recursion empieza en la obs 2



ar1    = 0.7*ar1(-1) + e                        ' AR: Memoria larga: shock se va desvaneciendo poco a poco
equation eq_ar1.ls ar1 ar1(1)


arma11 = 0.7*arma11(-1) + e + 0.4*e(-1)         ' ARMA(1,1)
equation eq_arma1.ls  arma11 ar(1) ma(1)


smpl @all
series ma1      = e + 0.4*e(-1)                 ' MA(1):  memoria corta: shock desaparece abruptamente
equation eq_ma1.ls  ma1 ma(1)


series arima111 = @cumsum(arma11)               ' ARIMA(1,1,1) = ARMA(1,1) acumulado
' >>> CLAVE: "integrar" (la I de ARIMA) = sumar acumulado. Diferenciar lo deshace.
equation eq_arima111.ls  d(arima111) ar(1) ma(1)

series e = nrnd                                 ' ruido blanco N(0,1)
series rw       = @cumsum(e)                    ' ARIMA(0,1,0) = random walk = ruido acumulado


group g_sim ar1 ma1 arma11 arima111 rw
g_sim.line(m)                                   ' (m) = un panel por serie

' Correlogramas (ACF/PACF), 20 rezagos
' >>> CLAVE de lectura:
'     AR(p): ACF decae gradualmente, PACF se corta en p
'     MA(q): ACF se corta en q, PACF decae
'     ARMA : ambas decaen
'     I(1) : ACF decae MUY lento (casi 1 en todos los rezagos)
'Q de Ljung-Box: H0: No hay autocorrelación en la serie hasta el rezago k
ar1.correl(20)
ma1.correl(20)
arma11.correl(20)
arima111.correl(20)
rw.correl(20)


' ADF (H0: raiz unitaria). Esperado: rechazar en ar1/ma1/arma11, no rechazar en arima111/rw
ar1.uroot(adf, const, info=sic)
ma1.uroot(adf, const, info=sic)
arma11.uroot(adf, const, info=sic)
arima111.uroot(adf, const, info=sic)
rw.uroot(adf, const, info=sic)

' Estacionaria en tendencia: con "const" parece I(1); con "trend" se rechaza H0
series x_tr = 0
smpl @first+1 @last
x_tr = 0.5 + 0.75*x_tr(-1) + 0.01*@trend + 1.5*nrnd
smpl @all
x_tr.uroot(adf, const, info=sic)
x_tr.uroot(adf, trend, info=sic)


' Quick > Automatic ARIMA Forecasting
' Estima usando toda la muestra 200 y escoge el menor valor de BIC (evaluación dentro de la muestra)

ar1.autoarma(tform=none, select=sic, smpl="1 200", agraph, atable) ar1_f c
ma1.autoarma(tform=none, select=sic, smpl="1 200", agraph, atable) ma1_f c

' atable = tabla de criterios por modelo ; fgraph = grafico del pronostico

if @pageexist("sim2") then
  pagedelete sim2
endif
pagecreate(page=sim2) u 500
rndseed 2026                                    
series e = nrnd   
series ma1      = e + 0.4*e(-1) 
ma1.autoarma(tform=none, select=sic, smpl="1 500", agraph, atable) ma1_f c

' Muestra corta (N=200): Ruido muestral hace que AR(1) y MA(1) tengan SSR similar; el BIC falla al desempatar

' Muestra grande (N=500): Consistencia asintotica del BIC; diluye el ruido y selecciona el MA(1) real



'=====================================================================
' BLOQUE 2. ESTACIONARIEDAD EN DATOS REALES 
'=====================================================================
pageselect fiji
smpl @all

' Opciones: const / trend / none ; dif=1 (primera diferencia) ;
'           info=sic (rezagos por criterio de Schwarz) ; maxlag=4 (datos anuales, 44 obs)
' >>> CLAVE: H0 = raiz unitaria (d=1). No rechazar en niveles y rechazar en
'     diferencias => la serie es I(1).

' Fiji
lrgdp_fiji.uroot(adf, trend, info=sic, maxlag=4)          ' niveles con tendencia
lrgdp_fiji.uroot(adf, const, info=sic, maxlag=4)          ' niveles solo constante
lrgdp_fiji.uroot(adf, const, dif=1, info=sic, maxlag=4)   ' primera diferencia

' Australia
lrgdp_aus.uroot(adf, trend, info=sic, maxlag=4)
lrgdp_aus.uroot(adf, const, info=sic, maxlag=4)
lrgdp_aus.uroot(adf, const, dif=1, info=sic, maxlag=4)

' Resultado esperado: ambas I(1) -> habilita cointegracion (Bloque 5)


'=====================================================================
' BLOQUE 3. DIAGNOSTICO DE RESIDUOS 
'=====================================================================
pageselect fiji
smpl 1972 2013

' 3a. Modelo estatico en niveles (puente con regresion espuria de clase 1)
equation eq3_niveles.ls lrgdp_fiji c lrgdp_aus
eq3_niveles.resids(g)                     ' residuos: ciclos largos = autocorrelacion
eq3_niveles.correl(12)                    ' ACF/PACF de residuos + Q de Ljung-Box
eq3_niveles.auto(2)                       ' Breusch-Godfrey LM, 2 rezagos

' 3a. Modelo estatico en diferencias
equation eq3_0.ls d(lrgdp_fiji) c d(lrgdp_aus)
eq3_0.resids(g)                     ' residuos: ciclos largos = autocorrelacion
eq3_0.correl(12)                    ' ACF/PACF de residuos + Q de Ljung-Box
eq3_0.auto(2)                       ' Breusch-Godfrey LM, 2 rezagos

'Interpretacion del coeficiente: 
'	Logaritmos: cambios porcentuales del PBI; 
'	Diferencias logarítmicas: cambios en crecimiento, medidos en puntos porcentuales.

' 3b. Agregar el rezago propio y de la covariable
equation eq3_1.ls d(lrgdp_fiji) c d(lrgdp_fiji(-1)) d(lrgdp_aus) d(lrgdp_aus(-1))
eq3_1.correl(12)
eq3_1.auto(2)
' >>> CLAVE: con variable dependiente rezagada, el Durbin-Watson ya NO es valido.
'     Usar Breusch-Godfrey (auto).

' Heterocedasticidad (H0: varianza constante)
eq3_1.hettest(type=white)           ' White
equation eq3_1.ls(cov=white) d(lrgdp_fiji) c d(lrgdp_fiji(-1)) d(lrgdp_aus) d(lrgdp_aus(-1))


' 3c. Un rezago adicional. Sintaxis de rango: x(-1 to -2) = x(-1) x(-2)
series dlf = d(lrgdp_fiji) 
series dla = d(lrgdp_aus) 
equation eq3_2.ls dlf c dlf(-1 to -2) dla(0 to -2)
eq3_2.auto(2)

' Comparar: si eq3_1 ya no tiene autocorrelacion, el rezago extra sobra (ver AIC/BIC)


'=====================================================================
' BLOQUE 4. TEST DE WALD Y VARIABLES DUMMY
'=====================================================================
pageselect fiji
smpl @all

series d2000 = (@year=2000)         ' impulso: 1 solo en 2000 (golpe de Estado)
series s2000 = (@year>=2000)        ' escalon: 1 desde 2000 (cambio de nivel permanente)
group g_dum d2000 s2000
g_dum.line(m)

smpl 1972 2013
equation eq4_dummy.ls d(lrgdp_fiji) c d(lrgdp_fiji(-1)) d(lrgdp_aus) d(lrgdp_aus(-1)) d2000 s2000
eq4_dummy.representations                 ' >>> CLAVE: ver numeracion de c(i) antes de usar Wald
' c(1)=c  c(2)=fiji(-1)  c(3)=aus  c(4)=aus(-1)  c(5)=d2000  c(6)=s2000

' Wald: restricciones lineales sobre coeficientes
eq4_dummy.wald c(5)=0, c(6)=0             ' significancia conjunta de las dos dummies
eq4_dummy.wald c(5)=0                     ' solo el impulso (equivale al t-stat al cuadrado)
eq4_dummy.wald c(2)+c(3)+c(4)=1           ' elasticidad de largo plazo = 1:
                                    '   (c3+c4)/(1-c2)=1  <=>  c2+c3+c4=1

'pbi_fiji=(elasticidad de largo plazo) * (pbi_australia)
' elasticidad de largo plazo = (c3+c4)/(1-c2)

' Test de de Chow para cambio estructural: quiebre en 2000 sobre el modelo SIN dummies
eq3_1.chow 2000                     ' H0: no hay cambio en los coeficientes


'Datos extendidos incluyendo el periodo covid donde probablemente haya cambio estructural
if @pageexist("fiji_new") then
  pagedelete fiji_new
endif
pagecreate(page=fiji_new) a 1970 2025
import "Fiji.xlsx" range=Fiji_new colhead=1 na="#N/A" @id @date(date) @smpl @all
equation eqcovid1.ls dlog(rgdp_fiji) c dlog(rgdp_aus)
eqcovid1.chow 2020                     ' Cambio estructural en Covid

 ' Impulso: Solo el impacto puntual de 2020 + Escalón: El cambio permanente que inicia en 2021
equation eqcovid2.ls dlog(rgdp_fiji) c dlog(rgdp_aus) (@year=2020)   (@year>=2021)                 


'=====================================================================
' BLOQUE 5. COINTEGRACION DE DOS VARIABLES
'=====================================================================
pageselect fiji
smpl @all
series lrgdp_fiji =log(rgdp_fiji)
series lrgdp_aus=log(rgdp_aus)
group g_eg lrgdp_fiji lrgdp_aus
g_eg.coint(method=eg)
g_eg.coint(method=eg, trend=linear)

' Test de cointegracion de Engle Granger: solo constante, rezagos por criterio SIC (máx. 9) -> 0 rezagos, valores p de MacKinnon (1996), n efectivo = 43.
' Resultado: evidencia moderada de cointegración entre LRGDP_FIJI y LRGDP_AUS (tau p = 0.026 y 0.045; z-stat de AUS p = 0.065 no rechaza H0) con constante pero debil con constante+tendencia

equation eq5_coint1.cointreg(method=fmols, trend=const) lrgdp_fiji lrgdp_aus
equation eq5_coint2.cointreg(method=fmols, trend=linear) lrgdp_fiji lrgdp_aus
' Hansen Lc (H0: cointegración): no rechaza con C (p=0.17) ni con C T (p>0.20) -> consistente con cointegración hallada con el test de Engle Granger


'=====================================================================
' BLOQUE 6. PROYECCIONES
'=====================================================================
pageselect fiji

' Fiji: estimar hasta 2008, pronosticar 2009-2013 (se conoce el dato real)
smpl 1970 2008
equation eq6_proj.ls d(log(rgdp_fiji)) c d(log(rgdp_aus))


' Dentro de muestra
eq6_proj.fit(e) lf_in                    ' ajuste estatico en el periodo de estimacion


' Fuera de muestra
smpl 2009 2013
eq6_proj.forecast(e, g) lf_dyn lf_dyn_se ' DINAMICO: usa sus propios pronosticos (errores se acumulan)


eq6_proj.fit(e, g) lf_sta lf_sta_se      ' ESTATICO: un paso adelante con datos observados
' >>> CLAVE: la ecuacion esta en d(log(rgdp_fiji)), pero EViews pronostica el NIVEL rgdp_fiji.
' Pregunta para la clase: por que estatico y dinamico coinciden en 2009?


'En 2009 ambos métodos parten del mismo valor inicial rezagado, el cual es el dato real observado de 2008. Divergen a partir de 2010: El dinámico empieza a alimentar el modelo con sus propios valores proyectados, mientras el estático sigue usando datos observados.



' Graficar el valor real, el valor proyectado con modelo estatico y el valor proyectado con modelo dinamico
smpl 2000 2013
delete(noerr) gr_fiji_f
graph gr_fiji_f.line rgdp_fiji lf_dyn lf_sta
show gr_fiji_f


'=====================================================================
' BLOQUE 7. OBJETO MODELO: ESCENARIOS '=====================================================================

import "Fiji.xlsx" range=Fiji colhead=1 na="#N/A" @id @date(date) @smpl @all
pageselect fiji
smpl @all
delete(noerr) m_fiji gr_esc gr_dif rgdp_fiji_0 rgdp_fiji_1 gr_sto


' Ecuacion del modelo en diferencias
smpl 1972 2013
equation eq_mod.ls dlog(rgdp_fiji) c dlog(rgdp_aus) 

' Shock: PIB de Australia cae 5% solo en 2000
' >>> CLAVE: la variable alternativa debe llamarse <exogena>_1 (sufijo del "Scenario 1")
smpl @all
series rgdp_aus_1 = rgdp_aus
smpl 2000 2000
rgdp_aus_1 = rgdp_aus *0.95
smpl @all

' Crear modelo y configurar escenarios
model m_fiji
m_fiji.merge eq_mod                 ' agrega la ecuacion de rgdp_fiji
m_fiji.scenario "Scenario 1"        ' activar Scenario 1
m_fiji.override rgdp_aus           ' en Scenario 1, rgdp_aus se reemplaza por rgdp_aus_1
m_fiji.scenario "Baseline"          ' volver al Baseline como escenario activo
m_fiji.scenario(c) "Scenario 1"     ' Scenario 1 como escenario de comparacion

' Opciones de solve: s=d deterministico ; d=s estatico / d=d dinamico ;
'                    a=t resuelve Baseline (_0) y Scenario 1 (_1) a la vez
smpl 2000 2013

' s=d deterministico (errores=0) | s=s estocastico (simula errores) 
' d=d dinamico (rezagos simulados) | d=s estatico (rezagos observados) 
' a=t resuelve Baseline (_0) y Scenario 1 (_1) a la vez

' 8a. ESTATICO: rgdp_fiji(-1) toma el dato observado
m_fiji.solve(s=d, d=s, a=t)
series dif_est = 100*log(rgdp_fiji_1/rgdp_fiji_0)   ' diferencia en %
' Esperado: efecto negativo en 2000, positivo en 2001 (rebote via dlog); cero despues
' Cada anio parte del PIB observado de Fiji en t-1. La caida de 2000 no se arrastra

' 8b. DINAMICO:
m_fiji.solve(s=d, d=d, a=t)
series dif_din = 100*log(rgdp_fiji_1/rgdp_fiji_0)
' >>> Cada anio parte del PIB simulado de Fiji en t-1. En 2001, ' Fiji ya esta 5.57% abajo y el rebote compensa esa caida (-5.57+5.57=0).

' Verificacion: solve dinamico (baseline) = forecast dinamico de la ecuacion
eq_mod.forecast lf_chk
show rgdp_fiji_0 lf_chk

' Graficos
smpl 1995 2013
graph gr_esc.line rgdp_fiji rgdp_fiji_0 rgdp_fiji_1   ' actual, base, alternativo (dinamico)
smpl 2000 2013
graph gr_dif.bar dif_est dif_din                         ' diferencia en el tiempo
show gr_esc
show gr_dif


'SOLUCION ESTOCASTICA

' Solve estocastico: s=b guarda medias y bandas de confianza (95% por defecto)
' r=1000 : Número de repeticiones (1000 por defecto)
' i=n :  innovaciones para repeticiones ~ Normal (por defecto); para bootstrap usar i=b
smpl 2000 2013
m_fiji.stochastic(i=n, r=1000)
m_fiji.solve(s=b, d=d, a=t)
smpl 1995 2013


' Grafico automatico del modelo. Opciones del makegraph:
' a   : Muestra la serie real (actuals).
' c   : Muestra el escenario base/de comparación.
' s=b : Dibuja la media y las bandas de confianza estocásticas.
delete(noerr) gr_sto
m_fiji.makegraph(a, c, s=b) gr_sto rgdp_fiji
show gr_sto



'MODELO CON REZAGO
delete(noerr) rgdp_fiji_0* rgdp_fiji_1*
smpl 1972 2013
equation eq_mod2.ls dlog(rgdp_fiji) c dlog(rgdp_aus) dlog(rgdp_fiji(-1)) 

smpl @all
series rgdp_aus_1 = rgdp_aus
smpl 2000 @last
rgdp_aus_1 = rgdp_aus *1.05
smpl @all

' Crear modelo y configurar escenarios
model m_fiji2
m_fiji2.merge eq_mod2                ' agrega la ecuacion de lrgdp_fiji
m_fiji2.scenario "Scenario 1"        ' activar Scenario 1
m_fiji2.override rgdp_aus           ' en Scenario 1, rgdp_aus se reemplaza por rgdp_aus_1
m_fiji2.scenario "Baseline"          ' volver al Baseline como escenario activo
m_fiji2.scenario(c) "Scenario 1"     ' Scenario 1 como escenario de comparacion

smpl 2000 2013
m_fiji2.stochastic(i=n, r=1000)
m_fiji2.solve(s=b, d=d, a=t)
smpl 1995 2013

delete(noerr) gr_sto2
m_fiji2.makegraph(a, c, s=b) gr_sto2 rgdp_fiji
show gr_sto2


smpl 2000 2013 
series dif_sto2 = 100*log(rgdp_fiji_1m/rgdp_fiji_0m)
 dif_sto2.line


' CIERRE

smpl @all
wfsave clase2_fiji.wf1


' 

' Adicional. Costa Rica: IED trimestral, modelo solo con sus rezagos, pronostico real hacia adelante
' >>> AJUSTAR nombre de archivo, hoja y variable
if @pageexist("cri") then
  pagedelete cri
endif
pagecreate(page=cri) q 2005q1 2027q4
import "cri.xlsx" range="Sheet3!A2:F94" colhead=1 na="#N/A" @id @date(fecha) @smpl @all

smpl 2005q1 2026q2
equation eq_fdi.ls fdi c fdi(-1 to -4)          ' AR(4) con rezagos explicitos

smpl 2026q3 2027q4
eq_fdi.forecast(g) fdi_f fdi_f_se               ' dinamico por defecto
series fdi_hi = fdi_f + 1.96*fdi_f_se
series fdi_lo = fdi_f - 1.96*fdi_f_se

smpl 2020q1 2027q4
delete(noerr) gr_fdi
graph gr_fdi.line fdi fdi_f fdi_lo fdi_hi
show gr_fdi




