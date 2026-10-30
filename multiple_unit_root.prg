'Las subrutinas comienzan con subroutine nombrederutina(tipo de objeto y su nombre)
'Los tipos de objetos pueden ser: series, scalar, string, matrix, equation, model, etc
' La rutina termina con endsub al final

subroutine multiple_unit_root(string vars)

%vars = vars
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

endsub


