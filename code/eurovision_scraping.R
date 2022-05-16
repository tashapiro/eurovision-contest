library(rvest)
library(tidyverse)
library(countrycode)
library(jsonlite)

#Web Scraping Events by Year ----
url_events<-'https://eurovision.tv/events'

events<-url_events%>%
  read_html()%>%
  html_elements("div.relative")%>%
  html_elements("h4")%>%
  html_text()

event_links<-url_events%>%
  read_html()%>%
  html_elements("div.w-full")%>%
  html_elements("a.absolute")%>%
  html_attr("href")

events<-trimws(str_replace_all(events,"\n",""))

countries<-url_events%>%
  read_html()%>%
  html_elements("div.relative")%>%
  html_elements("span.px-4")%>%
  html_text()

countries<-countries[-3]

by_year<-data.frame(
  event = events,
  host_city = str_sub(events, start=1, end=nchar(events)-4),
  host_country = str_replace_all(countries,"\n",""),
  year = str_sub(events, start=-4),
  event_link = event_links
)



#Scrape Participants ----
get_participants<-function(url){
  artists<-url%>%
    read_html()%>%
    html_elements(".text-xl")%>%
    html_elements("span")%>%
    html_text()
  
  countries<-url%>%
    read_html()%>%
    html_elements(".space-x-1")%>%
    html_text()
  
  artist_links<-url%>%
    read_html()%>%
    html_elements(".group")%>%
    html_element(".absolute")%>%
    html_attr("href")
  
  songs<-url%>%
    read_html()%>%
    html_elements(".relative")%>%
    html_elements("div.text-base")%>%
    html_text()
  
  data <-data.frame(
                    artist = artists,
                    song = songs, 
                    country = countries,
                    link = artist_links,
                    event_link = rep(url,length(artists)))
  
  data
}


#Get Information for All Participants
df_participants<-data.frame()
for (i in by_year$event_link){
  new_link <- paste0(i,"/participants")
  df<-get_participants(new_link)
  df_participants<-rbind(df_participants,df)
}

by_year$year<-as.numeric(by_year$year)

#Get Rankings for Semi Finals, Different URLs based on different Years ----

df_semis<-data.frame()
for(i in by_year$event_link[by_year$year<2008 & by_year$year>2004]){
  new_link<-paste0(i,"/semi-final")
  table<-new_link%>%
    read_html()%>%
    html_elements("table")%>%
    html_attr("x-data")
  json<-substr(table,19,nchar(table)-3)
  json<- gsub("\\\\","\\",json)
  json<-str_replace_all(json,"u0022",'\\"')
  data<-fromJSON(json)
  data<-data%>%unnest(c(participant, country))
  data$event_link<-i
  data$round<-"Semi-Final"
  df_semis<-rbind(df_semis, data)
}

df_semis1<-data.frame()
for(i in by_year$event_link[by_year$year>=2008]){
  new_link<-paste0(i,"/first-semi-final")
  table<-new_link%>%
    read_html()%>%
    html_elements("table")%>%
    html_attr("x-data")
  json<-substr(table,19,nchar(table)-3)
  json<- gsub("\\\\","\\",json)
  json<-str_replace_all(json,"u0022",'\\"')
  data<-fromJSON(json)
  data<-data%>%unnest(c(participant, country))
  data$event_link<-i
  data$round<-"First Semi-Final"
  df_semis1<-rbind(df_semis1, data)
}

df_semis2<-data.frame()
for(i in by_year$event_link[by_year$year>=2008]){
  new_link<-paste0(i,"/second-semi-final")
  table<-new_link%>%
    read_html()%>%
    html_elements("table")%>%
    html_attr("x-data")
  json<-substr(table,19,nchar(table)-3)
  json<- gsub("\\\\","\\",json)
  json<-str_replace_all(json,"u0022",'\\"')
  data<-fromJSON(json)
  data<-data%>%unnest(c(participant, country))
  data$event_link<-i
  data$round<-"Second Semi-Final"
  df_semis2<-rbind(df_semis2, data)
}

df_all_semis<-rbind(df_semis, df_semis1, df_semis2)

#Get Rankings for Finals----
#From 2022 to 2004, information is listed under "Grand Final" url
df_final1<-data.frame()
for(i in by_year$event_link[by_year$year>=2004]){
  new_link<-paste0(i,"/grand-final")
  table<-new_link%>%
    read_html()%>%
    html_elements("table")%>%
    html_attr("x-data")
  json<-substr(table,19,nchar(table)-3)
  json<- gsub("\\\\","\\",json)
  json<-str_replace_all(json,"u0022",'\\"')
  data<-fromJSON(json)
  data<-data%>%unnest(c(participant, country))
  data$event_link<-i
  data$round<-"Final"
  df_final1<-rbind(df_final1, data)
}

#Before 2004, information is listed under "Final" url
df_final2<-data.frame()
for(i in by_year$event_link[by_year$year<2004]){
  new_link<-paste0(i,"/final")
  table<-new_link%>%
    read_html()%>%
    html_elements("table")%>%
    html_attr("x-data")
  json<-substr(table,19,nchar(table)-3)
  json<- gsub("\\\\","\\",json)
  json<-str_replace_all(json,"u0022",'\\"')
  data<-fromJSON(json)
  data<-data%>%unnest(c(participant, country))
  data$event_link<-i
  data$round<-"Final"
  df_final2<-rbind(df_final2, data)
}

#combine datasets for finals
df_all_finals<-rbind(df_final1, df_final2)

#combine semifinals and finals into one dataset
df_rankings<-rbind(df_all_semis, df_all_finals)

#combine ranking data with by year data
data<-df_rankings%>%left_join(by_year, by="event_link")%>%
  select(event, host_city, host_country, year, round, name, performance, 
         nickname, running_order, total_points, rank_ordinal, rank, qualified, winner,
         url, event_link)%>%
  rename(participant_country=nickname, 
         participant_name = name,
         song = performance,
         participant_link = url)%>%
  mutate(host_city= trimws(host_city),
         qualified = case_when(round=="Final"~NA, TRUE ~qualified))

#export data
write.csv(data, "eurovision_data.csv")
