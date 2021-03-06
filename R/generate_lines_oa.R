# Aim: find and re-add 'missing lines'
source("../pct-load/set-up.R")

# OA centroids
cents = readOGR(dsn = "D:/Users/earmmor/OneDrive - University of Leeds/Cycling Big Data/Data/England_oa_2011_centroids", layer = "england_oa_2011_centroids")
cents <- spTransform(cents, CRS("+init=epsg:4326"))
#WZ centroids
centsWZ <- readOGR(dsn = "D:/Users/earmmor/OneDrive - University of Leeds/Cycling Big Data/Data/England_wz_2011_centroids", layer = "england_wz_2011_centroids")
centsWZ <- spTransform(centsWZ, CRS(proj4string(cents))) # transform CRS
# this data is from place living while working to working at OA to WZ level despite claiming to be OA to OA
flow_cens = readr::read_csv("D:/Users/earmmor/OneDrive - University of Leeds/Cycling Big Data/Data/RF03EW_oa_v1/rf03ew_oa_v1.csv", col_names = FALSE)
names(flow_cens) <- c("Area of usual residence","Area of Workplace","People")
nrow(flow_cens) 

#load Cambridgeshire boudaries
boundary <- readRDS("../pct-data/cambridgeshire/z.Rds")
boundary <- spTransform(boundary, CRS(proj4string(cents))) # transform CRS
plot(boundary)

# subset the centroids for testing (comment to generate national data)
cents <- cents[boundary,]
plot(cents)
nrow(cents) #2470
centsWZ <- centsWZ[boundary,]
plot(centsWZ)
nrow(centsWZ) #818

o <- flow_cens$`Area of usual residence` %in% cents$code
summary(o)
d <- flow_cens$`Area of Workplace` %in% centsWZ$code
summary(d)
flow <- flow_cens[o & d, ] # subset OD pairs with o and d in study area
nrow(flow) #1406

omatch = match(flow$`Area of usual residence`, cents$code)
dmatch = match(flow$`Area of Workplace`, centsWZ$code)


cents_o = cents@coords[omatch,]
cents_d = centsWZ@coords[dmatch,]
summary(is.na(cents_o)) # check how many origins don't match
summary(is.na(cents_d))
geodist = geosphere::distHaversine(p1 = cents_o, p2 = cents_d) / 1000 # assign euclidean distanct to lines (could be a function in stplanr)
summary(is.na(geodist))

hist(geodist, breaks = 0:100)
flow$dist = geodist
flow = flow[!is.na(flow$dist),] # there are 36k destinations with no matching cents - remove
#flow = flow[flow$dist >= 20,] # subset based on euclidean distance
#flow = flow[flow$dist < 30,]
names(flow) = gsub(pattern = " ", "_", names(flow))
flow_twoway = flow
#flow = onewayid(flow, attrib = 5:256, id1 = "Area_of_usual_residence", id2 = "Area_of_Workplace")
#checked upto this point

#flow[1:2] = cbind(pmin(flow[[1]], flow[[2]]), pmax(flow[[1]], flow[[2]]))

nrow(flow) # down to 0.9m, removed majority of lines
#cents <- cents[,c(2,1)] # switch column order for the od2line function to work
cents_both <- rbind(cents, centsWZ)
lines = od2line2(flow = flow, zones = cents_both)

plot(lines)

class(lines)
length(lines)
lines = SpatialLinesDataFrame(sl = lines, data = flow)
names(lines)
proj4string(lines) = CRS("+init=epsg:4326") # set crs

#sum(lines$`AllMethods_AllSexes_Age16Plus`)
#summary(lines$`AllMethods_AllSexes_Age16Plus`)

# to be removed when this is in stplanr
od_dist <- function(flow, zones){
  omatch = match(flow[[1]], cents@data[[1]])
  dmatch = match(flow[[2]], cents@data[[1]])
  cents_o = cents@coords[omatch,]
  cents_d = cents@coords[dmatch,]
  geosphere::distHaversine(p1 = cents_o, p2 = cents_d)
}

lines$dist = od_dist(flow = lines@data, zones = cents_both) / 1000

summary(lines$dist)

#lines@data <- dplyr::rename(lines@data,
#                        msoa1 = Area_of_usual_residence,
#                        msoa2 = Area_of_Workplace,
#                        all = `AllMethods_AllSexes_Age16Plus`,
#                        bicycle = Bicycle_AllSexes_Age16Plus#,
                        #train = Train,
                        #bus = `Bus,_minibus_or_coach`,
                        #car_driver = `Driving_a_car_or_van`,
                        #car_passenger = `Passenger_in_a_car_or_van`,
                        #foot = On_foot,
                        #taxi = Taxi,
                        #motorbike = `Motorcycle,_scooter_or_moped`,
                        #light_rail = `Underground,_metro,_light_rail,_tram`,
                        #other = Other_method_of_travel_to_work
#)

lines$WorkAtHome_AllSexes_Age16Plus <- NULL

names(lines)

# generate the fastest routes
rf = line2route(l = lines, route_fun = route_cyclestreet, plan = "fastest", base_url = "http://pct.cyclestreets.net/api/")
saveRDS(rf,file ="../pct-lsoa-test/data/rf_OA_Cam.Rds")

rq = line2route(l = lines, route_fun = route_cyclestreet, plan = "quietest", base_url = "http://pct.cyclestreets.net/api/")
saveRDS(rq,file ="../pct-lsoa-test/data/rq_OA_Cam.Rds")

