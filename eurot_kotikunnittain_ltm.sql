use Doctorex_mirror

--LTM-haku euroille kotikunnan mukaan
declare @alkupv datetime,@loppupv datetime

SET @alkupv='2023-09-01'
SET @loppupv='2024-08-31'

select HT, SUM(b.Eur) as Eur
into #TMPeurot
from
( select 'TT' as Maksajatyyppi,k.HLO as Tekija,la.ETNS as Tekijan_erikala,
 k.HT,ISNULL(r.PTR,0) as PotilasID,
 LEFT(dbo.udf_ConvertClarionDateTime(k.PVM,default),10) as Tapahtumapv,
 k.MK as EUR
 
 from kaynnit k 
 left join laakari la on k.HLO=la.SOTU
 left join rekist r on k.HT=r.HT
 
 where k.PVM between dbo.udf_GetClarionDay(@alkupv) and dbo.udf_GetClarionDay(@loppupv)
 and k.HT<>''
 
 UNION ALL
 
 select CASE WHEN ISNULL(l.MAKSAA_ITSE,0)=1 THEN 'Itsemaksavat'	
	WHEN l.ASX_NRO=0 THEN 'Maksaja puuttuu'			--tämä voidaan yhdistää Itsemaksaviin tässä tapauksessa			
	WHEN a.TYYPPI='H' THEN 'Henkilöasiakas'			--samoin tämä voisi olla Itsemaksavat
	WHEN a.TYYPPI='T' THEN 'Työterveyden asiakasyritys'
	WHEN a.TYYPPI='V' THEN 'Vakuutusyhtiö'
	WHEN a.TYYPPI='Y' THEN 'Yritysasiakas'
	ELSE ''
	END as Maksajatyyppi,
 l.LKRI as Tekija,la.ETNS as Tekijan_erikala,
 l.HT,ISNULL(r.PTR,0) as PotilasID,
 LEFT(dbo.udf_ConvertClarionDateTime(l.PVM,default),10) as Tapahtumapv,
  
 CAST(CASE WHEN ISNULL(l.AIKA,0)>0 
 THEN CAST((CAST(l.AIKA as float)-1)/360000 as decimal(9,5))
 WHEN ISNULL(l.AIKA,0)<0 THEN CAST((CAST(l.AIKA as float)+1)/360000 as decimal(9,5))
 ELSE l.LKM END *l.HINTA as decimal(8,2)) as EUR
  
 from laskut l left join asiakas a on l.ASX_NRO=a.NRO
 left join laakari la on l.LKRI=la.SOTU
 left join rekist r on l.HT=r.HT
  
 where l.PVM between dbo.udf_GetClarionDay(@alkupv) and  dbo.udf_GetClarionDay(@loppupv)
 and l.HT<>''

)b


group by YEAR(b.Tapahtumapv),MONTH(b.Tapahtumapv),b.HT,b.Maksajatyyppi

--yhdistetään
select r.KOTIKUNTA, sum(Eur) as EUR from #TMPeurot e
left join rekist r on r.HT=e.HT
group by KOTIKUNTA
order by sum(Eur) desc

