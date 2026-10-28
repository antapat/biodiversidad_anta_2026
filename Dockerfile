FROM rocker/shiny:4.4.2

ENV DEBIAN_FRONTEND=noninteractive \
    RENV_CONFIG_REPOS_OVERRIDE=https://cloud.r-project.org \
    SHINY_LOG_STDOUT=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c(\
    'shiny','bslib','reactable','mapgl','plotly','dplyr','sf',\
    'htmltools','jsonlite','geojsonsf','DBI','RPostgres'\
  ), repos='https://cloud.r-project.org')"

WORKDIR /srv/shiny-server/biodiversidad_anta
COPY app.R DESCRIPTION ./
COPY R ./R
COPY www ./www
COPY app-data ./app-data

RUN chown -R shiny:shiny /srv/shiny-server/biodiversidad_anta

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]
