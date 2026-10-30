cd "C:\Users\aalvarado\Downloads\proyecto_cri\"

fetch(d=per) cpi
dbopen per.edb

wfopen(type=excelxml) "cri.xlsx" range="Sheet3!B2:F94" colhead=1
pagestruct(freq=q, start=2005q1)

'Crear la base de datos
'dbcreate "cri.edb"
'Mover las series dentro de la ventana de la base de datos
' Se puede cerrar la ventana y en caso de volver a abrirla para eliminar y agregar mas objetos, simplemente usar el siguiente codigo
'dbopen cri.edb

close @all
fetch(d=cri) cpi fdi er gdp ca
pagestruct(freq=q, start=2005q1)














'Ejemplo expresiones en vez de genr
' Creando rezagos (-t)
genr cpi_l1 = cpi(-1)
genr cpi_l2 = cpi(-2)
genr cpi_l3 = cpi(-3)
genr cpi_l4 = cpi(-4)
equation eq3_slow
eq3_slow.ls gdp c cpi_l1 cpi_l2 cpi_l3 cpi_l4
equation eq3
eq3.ls gdp c cpi(-1 to -4)
' @TREND
genr tendencia = @trend
equation eq5_slow
eq5_slow.ls gdp c cpi tendencia
equation eq5
eq5.ls gdp c cpi @trend

'Promedio movil
genr promedio4 = @movav(cpi,4)
equation eq6_slow
eq6_slow.ls gdp c promedio4
equation eq6
eq6.ls gdp c @movav(cpi,4)



'Dummies temporales
genr q1 = @seas(1)
genr q2 = @seas(2)
genr q3 = @seas(3)
equation eq7_slow
eq7_slow.ls gdp c cpi q1 q2 q3
equation eq7
eq7.ls gdp c cpi @seas(1) @seas(2) @seas(3)



'Dummies de variables categoricas
smpl 2005q1 2012q1
series etapa = 1
smpl 2012q2 2018q4
series etapa = 2
smpl 2019q1 2022q4
series etapa = 3
smpl 2023q1 @last
series etapa = 4




smpl @all
genr etapa2 = (etapa=2)
genr etapa3 = (etapa=3)
genr etapa1 = (etapa=1)
equation eq8_slow.ls gdp c ca er fdi cpi etapa1 etapa2 etapa3  

equation eq8.ls gdp c ca er fdi cpi @expand(etapa,@droplast)




'Ejemplo de Paginas Enlazadas
' Crear pagina mensual
wfcreate(page=mensual) m 2025m1 2025m12
series x = 10*(@trend+1)
' Crear pagina trimestral y enlazar x
pagecreate(page=trimestral) q 2025q1 2025q4
link x_link.linkto(c=sum) mensual::x
show x_link


' Modificar la serie original
pageselect mensual
series x = 20*(@trend+1)
' Ver el link actualizado
pageselect trimestral
show x_link




'=========================================

wfcreate untitled q 2005q1 2029q4
'Conceptos reliminares
!n = 4        ' Valor numerico temporal
show !n
scalar n = 4  ' Se conserva en el workfile

%texto="palabras" ' Almancena texto temporal
show %texto

' Ejemplo de loops
'inicia el bucle con !i = 1 y establece que llegará hasta 3.
for !i = 1 to 3
    show !i
next



close @all

'Economia CRI: IED trimestral, modelo basado en espectativas de flujos de capital, pronostico hacia adelante
fetch(d=cri) cpi fdi er gdp ca 

expand 2005q1 2029q4

%vars = "cpi er ca gdp"
for %v {%vars}
	smpl 2005q1  2027q1
     {%v}.autoarma(select=sic)  {%v}2
	smpl 2028q1  2029q4
series  {%v}={%v}2
next



smpl @all
series rgdp = (gdp*er)/cpi           ' PIB real en moneda local
rgdp.hpf(lambda=1600) rgdp_trend ' filtro HP para PBI real en moneda local 



gdp.hpf(lambda=1600) gdp_trend ' filtro HP para PBI real en moneda extranjera



series fdi_ann = fdi + fdi(-1) + fdi(-2) + fdi(-3)
series gdp_trend_ann = gdp_trend + gdp_trend(-1) + gdp_trend(-2) + gdp_trend(-3)
series cf_gdp = 100 * fdi_ann / gdp_trend_ann



series ca_gdp = 100*ca/gdp       ' cuenta corriente, % of GDP
series infl  = dlog(cpi)                 ' inflacion, y/y %
series lrgdp=log(rgdp)



%vars = "rgdp infl ca_gdp cf_gdp"
!n = @wcount(%vars)
show !n


%vars = "rgdp infl ca_gdp cf_gdp"
%v = @word(%vars, 3)
show %v



%texto = "ABCDEF"
!pos1 = @instr(%texto, "CD")
show !pos1 ' Encuentra "CD" en la tercera posición.



%texto = "ABCDEF"
!pos2 = @instr(%texto, "XY") ' No encuentra "XY"
show !pos2



' Hacemos una inspeccion de como extraer los datos relevantes. Se puede guardar variables relevantes con el atributo "save="
lrgdp.uroot(adf, const, maxlag=11, info=sic, save=temp) 




' ---- ADF unit root summary: level, max lag 11, BIC (SIC) ----
%vars  = "lrgdp infl ca_gdp cf_gdp er"
%specs = "const trend none"

!nvars  = @wcount(%vars)

table(!nvars+2, 10) res
res(1,2) = "Intercept"
res(1,5) = "Trend + Intercept"
res(1,8) = "None"
for !j = 0 to 2
  res(2, 2+3*!j) = "Lag"
  res(2, 3+3*!j) = "Prob."
next


for !i = 1 to !nvars
  %v = @word(%vars, !i)
  res(2+!i, 1) = %v

  for !j = 1 to 3
    %s = @word(%specs, !j)
    {%v}.uroot(adf, {%s}, maxlag=11, info=sic, save=temp)
	res(2+!i, 2+3*(!j-1)) = temp(2,1)  ' numero de rezago seleccionado
	res(2+!i, 3+3*(!j-1)) = temp(4,1)  ' P-value
  next
delete temp
next
close @objects
show res

'Uso de subrutina.
' include: incorpora y ejecuta un archivo de programa (.prg) externo.
' call: ejecuta una subrutina, pasando los argumentos especificados.
' ver estructura de programa multiple_unit_root.prg

include multiple_unit_root
%vars  = "lrgdp infl"
call  multiple_unit_root(%vars)
show res




'CF = CF_{t-1} + E_t[Y_{t+4}] + E_t[pi_{t+4}] + E_t[CA_{t+4}] + e

'Aplicacion de Ha, Kim, Kose, & Warnock, (2026)



series f_gdp  = lrgdp(4)              ' E_t[Y_{t+4}]
series f_infl = infl(4)               ' E_t[pi_{t+4}]
series f_ca   = ca_gdp(4)             ' E_t[CA_{t+4}]



equation eq.ls cf_gdp c cf_gdp(-1) d(f_gdp) f_infl f_ca @trend
eq.correl
eq.auto(4)


equation eq.ls cf_gdp c  cf_gdp(-1) cf_gdp(-4) d(f_gdp) f_infl f_ca @trend
eq.correl
eq.auto(4)



equation eq.ls cf_gdp c  cf_gdp(-1) cf_gdp(-4) d(f_gdp) f_infl f_ca @trend @seas(2) @seas(3)  @seas(4) 
eq.correl
eq.auto(4)



equation eq.ls cf_gdp c  cf_gdp(-1) ma(4) d(f_gdp) f_infl f_ca @trend  
eq.correl




smpl @all
equation eq.ls cf_gdp c  cf_gdp(-1) ma(4) d(f_gdp) f_infl f_ca @trend  
eq.forecast(e, g, forcsmpl="2026q3 2029q4") cf_gdpf
smpl 2022q1 @last
delete(noerr) gr_proj
graph gr_proj.line cf_gdpf  cf_gdp
show gr_proj


'Muestra para estimacion
%esmpl="@first 2026q2"

'Muestra para el forecast
%fsmpl="2026q2 2028q4"

'Bootstrap errors? 1=yes, 0=no, use normal distribution
!boot=0

'Coefficient uncertainty? 1=yes, 0=no coefficient uncertanty
!coefu=0

'Number of bands in fanchart starting from 90%. 
'For example, !numb=1 plots 90% band and the mode, 
'!numb=2 plots 90% band, 45% band and the mode 
!numb=6

'Do not change the 2 parameters below unless you are adapting the code
' for your own model
'Name of the model to be used for constructing a fan chart
%modname="mod"

'Variable to forecast (has to be one of the model variables)
%varname="cf_gdp"

smpl {%esmpl}
'=========== Model specification =========
eq.makemodel({%modname}) 
'=============== Main Fan Chart Program==============

''%quant_array guarda los niveles de confianza de las bandas, p.ej. "90 60 30 1" si !numb=3. 'EViews usa cada nivel para calcular una banda en cada simulación estocástica.

%quant_array="90 "
!quant_step=90/!numb
!k=90-!quant_step
while !k>5 
%quant_array=%quant_array+@str(@round(!k))+" "
!k=!k-!quant_step
wend
%quant_array=%quant_array+"1"


'Recorremos cada nivel: simulamos el modelo al 90%, guardamos los límites, y repetimos 'para 60% y 30%. La corrida al 1% da la línea central (en la práctica, la mediana). 

'Para cada trimestre hay !num_simul escenarios de la var. dependiente, generados con el 'modelo estimado y distintos errores (bootstrap o normal). 

'P.ej., cuando %quant=60, !alfa_ratio=0.6: EViews ordena los escenarios de menor a mayor, 'recorta el 20% más bajo y el 20% más alto, y devuelve los límites. Repitiendo con 90%, '60% y 30% obtenemos las capas del abanico.

delete(noerr) g2
group g2

for %quant {%quant_array}  
	!alfa={%quant} 'current confidence level
	smpl {%fsmpl}
	!alfa_ratio=!alfa/100 
	
	!num_simul=100000

	if @abs(!boot-1)<0.0001 then 'boot strap errors
		if @abs(!coefu-1)<0.0001 then 'coefficient uncertainty
			{%modname}.stochastic(i=b, b=!alfa_ratio,c=t,r=!num_simul)
		else 'no coefficient uncertainty
			{%modname}.stochastic(i=b, b=!alfa_ratio,r=!num_simul)
		endif
	else 'normal errors
		if @abs(!coefu-1)<0.0001 then 'coefficient uncertainty
			{%modname}.stochastic(i=n, b=!alfa_ratio,c=t,r=!num_simul)
		else 'no coefficient uncertainty
			{%modname}.stochastic(i=n, b=!alfa_ratio,r=!num_simul)
		endif
	endif	
	

	{%modname}.solveopt(s=b,d=d)
	{%modname}.solve
	
	'Limitamos la muestra a un solo trimestre, el último observado, y ahí forzamos que el límite superior y el inferior sean iguales al dato real. Así el abanico nace de un punto conocido y se abre hacia el futuro.

	%first_elem_fsmpl=@wleft(%fsmpl,1)
	%second_elem_fsmpl=@wright(%fsmpl,1)
	
	smpl {%first_elem_fsmpl} {%first_elem_fsmpl}
	{%varname}_0h={%varname}
	{%varname}_0l={%varname}

	smpl {%first_elem_fsmpl}-6 {%second_elem_fsmpl}

'Cada simulación deja sus resultados en las mismas dos series, así que en cada vuelta las guardamos con el nivel de confianza en el nombre antes de que se sobrescriban. Después las vamos agregando al grupo en pares, inferior y superior, porque así las lee el gráfico de bandas.

	if !alfa<3 then
		%quant="0"
	endif
	series {%varname}_{%quant}h_={%varname}_0h
	series {%varname}_{%quant}l_={%varname}_0l
	g2.add {%varname}_{%quant}l_ {%varname}_{%quant}h_

next


'Después de congelar el gráfico, pintamos cada banda con un verde un poco más oscuro que la anterior: la del 90% es la más clara y el centro el más oscuro. Así la vista se va directo a los escenarios más probables. El último elemento es el dato observado, en azul y grueso

series p1={%varname}
g2.add {%varname} p1
freeze(fanchart, mode=overwrite) g2.band(o="modern")

fanchart.legend -display
for !i=1 to !numb+1
	!r=@round(0.2*255)
	!b=0
	!g=@round((1-0.175*@sqrt(!i) )*255)
	fanchart.setelem(!i) fcolor(@rgb(!r,!g,!b))
next
!numline=!numb+2
fanchart.setelem(!numline) fcolor(blue) lwidth(10)


fanchart.draw(shade,b, gray) {%fsmpl} 'fondo gris
show fanchart

smpl @all


