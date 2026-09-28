SELECT *
FROM Portfolio_Project..CovidDeaths
where continent is not null
order by 3,4

SELECT 
    location, 
    date, 
    total_cases,
    new_cases, 
    total_deaths, 
    population
FROM Portfolio_Project..CovidDeaths
ORDER BY 1,2

--looking at total cases vs total deaths
--Shows the likelyhood of dying if infected by Covid19
SELECT 
    location, 
    date, 
    total_cases, total_deaths, 
    ROUND((total_deaths * 100 /NULLIF((total_cases), 0)),3) Death_Ratio
FROM Portfolio_Project..CovidDeaths
WHERE continent is not null
ORDER BY 1,2

--Shows percentage of country population that got Covid19
SELECT 
    location, 
    date, 
    total_cases, 
    population, 
    ROUND((total_cases * 100 /NULLIF(population,0)),4) Infection_Rate
FROM Portfolio_Project..CovidDeaths
WHERE continent is not null
ORDER BY 1,2


--Countries with higest infection rate compared to population
SELECT 
    location, 
    MAX(total_cases) Highest_Infection_count, 
    population, 
    ROUND(max(total_cases * 100 /NULLIF(population,0)),3) Percent_population_infected
FROM Portfolio_Project..CovidDeaths
WHERE continent is not null
GROUP BY location, population
ORDER BY 4 desc

--Countries with highest death count
SELECT
    location, 
    MAX(cast(total_deaths as int)) Highes_Death_count
FROM Portfolio_Project..CovidDeaths
WHERE continent is not null
GROUP BY location
ORDER BY Highes_Death_count desc


--looking at total cases vs total deaths
--Shows the likelyhood of dying if infected by Covid19 in your continent
SELECT 
    continent, 
    location, date, 
    total_cases, 
    total_deaths, 
    ROUND((total_deaths* 100/NULLIF(total_cases,0)),3) Death_Ratio
FROM Portfolio_Project..CovidDeaths
WHERE continent is not null
ORDER BY 1,2

--Shows percentage of continent population that got Covid19
SELECT
continent, 
    location, 
    date, 
    total_cases, 
    population, 
    (total_cases/population)*100 Infection_Rate
FROM Portfolio_Project..CovidDeaths
WHERE continent is not null
ORDER BY 1,2

-- shows new cases, new deaths amd death ratio per day
SELECT  
    date, 
    sum(new_cases) Total_Cases, 
    sum(cast(new_deaths as int)), 
    ROUND((sum(cast(new_deaths as int)) * 100/NULLIF(sum(new_cases), 0)), 3) Death_Ratio
FROM Portfolio_Project..CovidDeaths
    where continent is not null
GROUP BY date
ORDER BY 1,2


--looking at total population vs vaccinations
SELECT
    death.continent, 
    death.location, 
    death.date, 
    death.population, 
    vacc.new_vaccinations, 
    SUM(cast(vacc.new_vaccinations as int)) over (partition by death.location order by death.location, death.date) Rolling_vaccinations
FROM CovidDeaths Death
JOIN CovidVaccinations vacc
    on Death.location =vacc.location
    and Death.date = vacc.date

WHERE death.continent IS NOT NULL
ORDER BY 2,3

--Rolling vaccinated vs population using CTE
With PopvsVac (continent, location,date,population,new_vaccinations,Rolling_vaccination) as
(
SELECT
    death.continent, 
    death.location, 
    death.date, 
    death.population, 
    vacc.new_vaccinations, 
    SUM(cast(vacc.new_vaccinations as int)) over (partition by death.location order by death.location, death.date) Rolling_vaccinations
FROM CovidDeaths Death
JOIN CovidVaccinations vacc
    on Death.location =vacc.location
    and Death.date = vacc.date
WHERE death.continent is not null
)
SELECT*, ROUND((Rolling_vaccination/population *100),3) VaccinatedPercentage
FROM PopvsVac

--Shows how quickly countries progressed through vaccination
SELECT 
    Location, 
    Max(total_vaccinations) as Total_Vaccinations, 
    MAX(people_vaccinated) as people_vacccinated,
    MAX(people_fully_vaccinated) as people_fully_vaccinated
FROM CovidDeaths
WHERE continent is not null
GROUP BY location
ORDER BY people_fully_vaccinated

-- Countries with highest death rate
SELECT
    location,
    MAX(total_cases) AS total_cases,
    MAX(cast(total_deaths as int)) AS total_deaths,
    ROUND(
        MAX(cast(total_deaths as int)) * 100.0 / NULLIF(MAX(total_cases), 0), 2
    ) AS death_rate_percentage
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY death_rate_percentage DESC;


--Countries with largest vaccination gap
SELECT
    death.location,
    MAX(death.population) AS population,
    MAX(cast(vacc.people_fully_vaccinated as int)) AS fully_vaccinated,
    MAX(death.population) - MAX(cast(vacc.people_fully_vaccinated as int)) AS unvaccinated_estimate
FROM CovidDeaths death
JOIN CovidVaccinations vacc
    ON death.location = vacc.location
    AND death.date = vacc.date
WHERE death.continent IS NOT NULL
GROUP BY death.location
ORDER BY unvaccinated_estimate DESC;

--Vaccination percentage of population
SELECT
    death.location,
    MAX(death.population) AS population,
    MAX(cast(vacc.people_fully_vaccinated as int)) AS fully_vaccinated,
    ROUND(
        MAX(cast(vacc.people_fully_vaccinated as int)) * 100.0 /
        NULLIF(MAX(death.population), 0), 3
    ) AS fully_vaccinated_percentage
FROM CovidDeaths death
JOIN CovidVaccinations vacc
    ON death.location = vacc.location
    AND death.date = vacc.date
WHERE death.continent IS NOT NULL
GROUP BY death.location
ORDER BY fully_vaccinated_percentage DESC;


-- Top 10 countries by Covid deaths per million
SELECT TOP 10
    location,
    MAX(convert(float, total_deaths_per_million)) AS deaths_per_million
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY deaths_per_million DESC;


--Ranking countries based on total number of deaths
WITH CountryDeaths AS
(
    SELECT
        location,
        MAX(cast(total_deaths as int)) AS total_deaths
    FROM CovidDeaths
    WHERE continent IS NOT NULL
    GROUP BY location
)
SELECT
    location,
    total_deaths,
    RANK() OVER (ORDER BY total_deaths DESC) AS death_rank
FROM CountryDeaths;

-- Analyzing Vaccination speed
WITH VaccinationChanges AS
(
    SELECT
        location,
        date,
        cast(total_vaccinations as int) Total_vaccinations,
        LAG(cast(total_vaccinations as int)) OVER
        (
            PARTITION BY location
            ORDER BY date
        ) AS previous_day_vaccinations
    FROM CovidVaccinations
    WHERE continent IS NOT NULL
)
SELECT
    location,
    date,
    total_vaccinations,
    previous_day_vaccinations,
    total_vaccinations - previous_day_vaccinations
        AS daily_vaccination_increase
FROM VaccinationChanges
WHERE previous_day_vaccinations IS NOT NULL
ORDER BY daily_vaccination_increase DESC;


-- Countries  with high cases but relatively low vaccination
SELECT
    d.location,
    MAX(d.total_cases) AS total_cases,
    MAX(d.population) AS population,
    MAX(cast(v.people_fully_vaccinated as int)) AS fully_vaccinated,

    ROUND(
        MAX(d.total_cases) * 100.0 /
        NULLIF(MAX(d.population), 0), 2
    ) AS infection_percentage,

    ROUND(
        MAX(cast(v.people_fully_vaccinated as int)) * 100.0 /
        NULLIF(MAX(d.population), 0), 2
    ) AS vaccination_percentage

FROM CovidDeaths d
JOIN CovidVaccinations v
    ON d.location = v.location
    AND d.date = v.date

WHERE d.continent IS NOT NULL
GROUP BY d.location
HAVING
    MAX(d.total_cases) * 100.0 / NULLIF(MAX(d.population), 0) > 5
    AND
    MAX(cast(v.people_fully_vaccinated as int)) * 100.0 / NULLIF(MAX(d.population), 0) < 40
ORDER BY infection_percentage DESC;

--  Comparing continents
SELECT
    continent,
    SUM(max_deaths) AS total_deaths
FROM
(
    SELECT
        continent,
        location,
        MAX(cast(total_deaths as int)) AS max_deaths
    FROM CovidDeaths
    WHERE continent IS NOT NULL
    GROUP BY continent, location
) AS CountryDeaths
GROUP BY continent
ORDER BY total_deaths DESC;


--CREATING VIEWS FOR LATER VISUALIZATION
create view Percent_Population_Vaccinated as
select death.continent, death.location, death.date, death.population, vacc.new_vaccinations, 
SUM(cast(vacc.new_vaccinations as int)) over (partition by death.location order by death.location, death.date) Rolling_vaccinations
from CovidDeaths Death
join CovidVaccinations vacc
    on Death.location =vacc.location
    and Death.date = vacc.date
where death.continent is not null

create view Continents_Deaths as
SELECT continent, SUM(max_deaths) AS total_deaths
FROM
( SELECT continent,location,
        MAX(cast(total_deaths as int)) AS max_deaths
    FROM CovidDeaths
    WHERE continent IS NOT NULL
    GROUP BY continent, location
) AS CountryDeaths
GROUP BY continent



create view Vaccination_percent as
SELECT
    death.location,
    MAX(death.population) AS population,
    MAX(cast(vacc.people_fully_vaccinated as int)) AS fully_vaccinated,
    ROUND(
        MAX(cast(vacc.people_fully_vaccinated as int)) * 100.0 /
        NULLIF(MAX(death.population), 0), 3
    ) AS fully_vaccinated_percentage
FROM CovidDeaths death
JOIN CovidVaccinations vacc
    ON death.location = vacc.location
    AND death.date = vacc.date
WHERE death.continent IS NOT NULL
GROUP BY death.location

create view Deaths_per_million as
SELECT TOP 10
    location,
    MAX(convert(float, total_deaths_per_million)) AS deaths_per_million
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location


create view Country_death_ranking as
WITH CountryDeaths AS
( SELECT
        location,
        MAX(cast(total_deaths as int)) AS total_deaths
    FROM CovidDeaths
    WHERE continent IS NOT NULL
    GROUP BY location)
SELECT
    location,
    total_deaths,
    RANK() OVER (ORDER BY total_deaths DESC) AS death_rank
FROM CountryDeaths;

create view Vacination_Speed as
WITH VaccinationChanges AS
(SELECT
        location,
        date,
        cast(total_vaccinations as int) Total_vaccinations,
        LAG(cast(total_vaccinations as int)) OVER
        (
            PARTITION BY location
            ORDER BY date
        ) AS previous_day_vaccinations
    FROM CovidVaccinations
    WHERE continent IS NOT NULL)
SELECT
    location,
    date,
    total_vaccinations,
    previous_day_vaccinations,
    total_vaccinations - previous_day_vaccinations
        AS daily_vaccination_increase
FROM VaccinationChanges
WHERE previous_day_vaccinations IS NOT NULL


Create view InfectionPercent_vs_VaccinationPercent as
SELECT
    d.location,
    MAX(d.total_cases) AS total_cases,
    MAX(d.population) AS population,
    MAX(cast(v.people_fully_vaccinated as int)) AS fully_vaccinated,

    ROUND(
        MAX(d.total_cases) * 100.0 /
        NULLIF(MAX(d.population), 0), 2
    ) AS infection_percentage,

    ROUND(
        MAX(cast(v.people_fully_vaccinated as int)) * 100.0 /
        NULLIF(MAX(d.population), 0), 2
    ) AS vaccination_percentage

FROM CovidDeaths d
JOIN CovidVaccinations v
    ON d.location = v.location
    AND d.date = v.date

WHERE d.continent IS NOT NULL

GROUP BY d.location

HAVING
    MAX(d.total_cases) * 100.0 / NULLIF(MAX(d.population), 0) > 5
    AND
    MAX(cast(v.people_fully_vaccinated as int)) * 100.0 / NULLIF(MAX(d.population), 0) < 40

create view Vaccination_progression as
SELECT 
    Location, 
    Max(total_vaccinations) as Total_Vaccinations, 
    MAX(people_vaccinated) as people_vacccinated,
    MAX(people_fully_vaccinated) as people_fully_vaccinated
FROM CovidDeaths
WHERE continent is not null
GROUP BY location

create view Cases_vs_Deaths as
SELECT 
    continent, 
    location, date, 
    total_cases, 
    total_deaths, ROUND((total_deaths * 100 /NULLIF((total_cases), 0)),3) Death_Ratio
FROM 
    Portfolio_Project..CovidDeaths
    where continent is not null

Create view Death_Ratio_Per_Day as
select 
    continent, 
    location, date, 
    total_cases, 
    total_deaths, 
    ROUND((total_deaths* 100/NULLIF(total_cases,0)),3) Death_Ratio
from 
    Portfolio_Project..CovidDeaths
    where continent is not null
    
    
    





























