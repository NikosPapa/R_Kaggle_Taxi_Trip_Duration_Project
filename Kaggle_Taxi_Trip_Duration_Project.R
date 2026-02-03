install.packages("readxl")
library(readxl)
install.packages("ggplot2")
library(ggplot2)
install.packages("dplyr")
library(dplyr)
install.packages("caret")
library(caret)

# Data loading
taxi_data <- read.csv("train.csv")
str(taxi_data)

# ------------------------------ EDA ------------------------------ #

# Analyzing outliers
ggplot(taxi_data, aes(x = pickup_longitude)) +
  geom_histogram(bins = 100)

taxi_data %>% filter(pickup_longitude < -100)

ggplot(taxi_data, aes(x = pickup_latitude)) +
  geom_histogram(bins = 100)

ggplot(taxi_data, aes(x=dropoff_longitude)) + 
  geom_histogram(bins=100)

ggplot(taxi_data, aes(x = trip_duration)) +
  geom_histogram(bins = 100)

taxi_data %>% filter(trip_duration > 1000)

## Removing outliers (pickup_longitude)
avg_plong <- mean(taxi_data$pickup_longitude)
stdev_plong <- sd(taxi_data$pickup_longitude)

taxi_data_filter <- taxi_data %>% 
  filter(pickup_longitude < avg_plong+stdev_plong*3) %>% 
  filter(pickup_longitude > avg_plong-stdev_plong*3)

nrow(taxi_data_filter) # 1458277

ggplot(taxi_data_filter, aes(x = pickup_longitude)) +
  geom_histogram(bins = 100) # we get a normal distribution.

## Removing outliers (pickup_latitude)
avg_plat <- mean(taxi_data$pickup_latitude)
stdev_plat <- sd(taxi_data$pickup_latitude)

taxi_data_filter <- taxi_data_filter %>% 
  filter(pickup_latitude < avg_plat+stdev_plat*3) %>% 
  filter(pickup_latitude > avg_plat-stdev_plat*3)

nrow(taxi_data_filter) # 1424845

ggplot(taxi_data_filter, aes(x = pickup_latitude)) +
  geom_histogram(bins = 100) # we get a normal distribution. 

## Removing outliers (dropoff_longitude)
avg_dlong <- mean(taxi_data_filter$dropoff_longitude)
stdev_dlong <- sd(taxi_data_filter$dropoff_longitude)

taxi_data_filter <- taxi_data_filter %>% 
  filter(dropoff_longitude < avg_dlong+stdev_dlong*3) %>% 
  filter(dropoff_longitude > avg_dlong-stdev_dlong*3)

nrow(taxi_data_filter) # 1392725

ggplot(taxi_data_filter, aes(x=dropoff_longitude)) + 
  geom_histogram(bins=100)

## Removing outliers (dropoff_latitude)
avg_dlat <- mean(taxi_data_filter$dropoff_latitude)
stdev_dlat <- sd(taxi_data_filter$dropoff_latitude)

taxi_data_filter <- taxi_data_filter %>% 
  filter(dropoff_latitude < avg_dlat+stdev_dlat*3) %>% 
  filter(dropoff_latitude > avg_dlat-stdev_dlat*3)

nrow(taxi_data_filter) # 1372422

ggplot(taxi_data_filter, aes(x=dropoff_latitude)) + 
  geom_histogram(bins=100)

## Removing outliers (trip_duration): target variable
avg_duration <- mean(taxi_data_filter$trip_duration)
stdev_duration <- sd(taxi_data_filter$trip_duration)

taxi_data_filter <- taxi_data_filter %>% 
  filter(trip_duration < avg_duration+stdev_duration*3) %>% 
  filter(trip_duration > avg_duration-stdev_duration*3)

nrow(taxi_data_filter) # 1370538

ggplot(taxi_data_filter, aes(x=trip_duration)) + 
  geom_histogram(bins=100)

# We ended up removing around 6% of the original dataset
1-nrow(taxi_data_filter)/nrow(taxi_data)

# NA's check in our columns
colSums(is.na(taxi_data_filter)) # 0 NA's

# ------------------------------ Feature Engineering ------------------------------ #

# Trip duration features (pickup_datetime)
taxi_data_filter$pickup_month <- strftime(taxi_data_filter$pickup_datetime, '%m')

taxi_data_filter$pickup_day <- strftime(taxi_data_filter$pickup_datetime, '%d')

taxi_data_filter$pickup_hour <- strftime(taxi_data_filter$pickup_datetime, '%H', tz = 'EST')

mean_by_month <- taxi_data_filter %>% 
  group_by(pickup_month) %>% 
  summarise(mean_trip = mean(trip_duration))

mean_by_month

ggplot(mean_by_month, aes(x=pickup_month, y=mean_trip)) + geom_point()

mean_by_day <- taxi_data_filter %>% 
  group_by(pickup_day) %>% 
  summarise(mean_trip = mean(trip_duration))

mean_by_day

ggplot(mean_by_day, aes(x=pickup_day, y=mean_trip)) + geom_point()

mean_by_hour <- taxi_data_filter %>% 
  group_by(pickup_hour) %>% 
  summarise(mean_trip = mean(trip_duration))

mean_by_hour

ggplot(mean_by_hour, aes(x=pickup_hour, y=mean_trip)) + geom_point()

# Location based features (id2875421)
point_a <- c(40.76794, -73.98215)
point_b <- c(40.76560, -73.96463)

sum(abs(point_a-point_b)) # Manhattan distance

sqrt(sum((point_a-point_b)^2)) # Euclidean distance

## -- manhattan_distance
manhattan_distance <- function(p_lat, p_long, d_lat, d_long) {
  point_a <- c(p_lat, p_long)
  point_b <- c(d_lat, d_long)
  return (sum(abs(point_a-point_b)))
}

manhattan_distance(1,0,1,0) # function check

mapply(manhattan_distance ,
       taxi_data_filter$pickup_longitude,
       taxi_data_filter$pickup_latitude,
       taxi_data_filter$dropoff_longitude,
       taxi_data_filter$dropoff_latitude)

### Add a new column for the manhattan_distance
taxi_data_filter <- cbind(taxi_data_filter, manhattan_distance = mapply(manhattan_distance ,
       taxi_data_filter$pickup_longitude,
       taxi_data_filter$pickup_latitude,
       taxi_data_filter$dropoff_longitude,
       taxi_data_filter$dropoff_latitude))

### Correlation check and visualize trip_duration and distance
taxi_data_filter$rounded_manhattan_distance <- round(
  taxi_data_filter$manhattan_distance, 2)

mean_by_distance <- taxi_data_filter %>%
  group_by(rounded_manhattan_distance) %>%
  summarize(mean_trip = mean(trip_duration))

ggplot(mean_by_distance, aes(x=rounded_manhattan_distance, y=mean_trip)) + 
  geom_point()

cor(
  taxi_data_filter$rounded_manhattan_distance,
  taxi_data_filter$trip_duration) # 0.6994821 high correlation

## -- euclidean_distance
euclidean_distance <- function(p_lat, p_long, d_lat, d_long) {
  point_a <- c(p_lat, p_long)
  point_b <- c(d_lat, d_long)
  return (sqrt(sum((point_a-point_b)^2)))
}

euclidean_distance(1,0,1,0) # function check

mapply(euclidean_distance ,
       taxi_data_filter$pickup_longitude,
       taxi_data_filter$pickup_latitude,
       taxi_data_filter$dropoff_longitude,
       taxi_data_filter$dropoff_latitude)

### Add a new column for the manhattan_distance
taxi_data_filter <- cbind(taxi_data_filter, euclidean_distance = mapply(euclidean_distance ,
       taxi_data_filter$pickup_longitude,
       taxi_data_filter$pickup_latitude,
       taxi_data_filter$dropoff_longitude,
       taxi_data_filter$dropoff_latitude))

### Correlation check and visualize trip_duration and distance
taxi_data_filter$rounded_euclidean_distance <- round(
  taxi_data_filter$euclidean_distance, 2)

mean_by_distance_euclidean <- taxi_data_filter %>%
  group_by(rounded_euclidean_distance) %>%
  summarize(mean_trip = mean(trip_duration))

ggplot(mean_by_distance_euclidean, aes(x=rounded_euclidean_distance, y=mean_trip)) + 
  geom_point()

cor(
  taxi_data_filter$rounded_euclidean_distance,
  taxi_data_filter$trip_duration) # 0.7096476 high correlation

# Week day features 
taxi_data_filter$pickup_weekday <- strftime(taxi_data_filter$pickup_datetime, '%A', tz = 'EST')

mean_by_weekday <- taxi_data_filter %>%
  group_by(pickup_weekday) %>%
  summarize(mean_weekday = mean(trip_duration))

ggplot(mean_by_weekday, aes(x=pickup_weekday, y=mean_weekday)) + 
  geom_point() # higher trip duration during the weekdays

write.csv(taxi_data_filter, "C:\\Users\\user1\\Desktop\\taxi_data_final.csv", row.names = FALSE)

# ------------------------------ Modelling ------------------------------ #

taxi_data <- read.csv("taxi_data_final.csv")
str(taxi_data)

# Preparing data for modelling
onehot <- dummyVars(" ~ pickup_weekday", data=taxi_data)
dummy_variables <- data.frame(predict(onehot, newdata = taxi_data)) 

taxi_data <- cbind(taxi_data, dummy_variables)

# Final table 
taxi_data_modelling <- taxi_data[,c('vendor_id','passenger_count',
                                    'trip_duration','pickup_month',
                                    'pickup_day','pickup_hour',
                                    'manhattan_distance', 'euclidean_distance',
                                    'pickup_weekdayFriday', 'pickup_weekdayMonday',
                                    'pickup_weekdaySaturday', 'pickup_weekdaySunday',
                                    'pickup_weekdayThursday', 'pickup_weekdayTuesday',
                                    'pickup_weekdayWednesday')]


str(taxi_data_modelling) # if the input contains characters, convert them to numeric form.

# Build training and test data
train_test_split <- function(data, percentage) {
  
  data_with_row_id <- data %>% 
    mutate(id = row_number())
  
  set.seed(1234)
  training_data <- data_with_row_id %>%
    sample_frac(percentage)
  test_data <- anti_join(
    data_with_row_id,
    training_data,
    by='id'
  )
  
  training_data$id <- NULL
  test_data$id <- NULL
  
  return (list(training_data, test_data))
}

training_data <- train_test_split(taxi_data_modelling, 0.3)[[1]]
test_data <- train_test_split(taxi_data_modelling, 0.3)[[2]]

# Linear model 
taxi_linear_model <- lm(
  trip_duration ~ .,
  data=training_data)

summary(taxi_linear_model)

# Check the R-Squared on the test set
calc_rsquare <- function(y, y_pred) {
  return(cor(y, y_pred))
}

predictions <- predict(taxi_linear_model, test_data)

calc_rsquare(test_data$trip_duration, predictions) # 0.5283654, so the model does not overfit. 

## Visualize
test_data$lm_predictions <- predict(taxi_linear_model, test_data)

test_data_sample <- test_data %>% 
  sample_n(50000) # take a sample

ggplot(test_data_sample, aes(x=trip_duration, y=lm_predictions)) +
         geom_point() + xlim(0, 4000)

## Metrics from mltools
install.packages("mltools")
library(mltools)

# Check the Root Mean Squared Error
rmse(test_data$lm_predictions, test_data$trip_duration)

## RMSE: 365.1405 seconds
365/60 # this gives a difference of 6.083333 for the algorithm
## R Squared: 0.5278993

# Random Forest
install.packages("ranger")
library(ranger)

rf_model <- ranger(
  trip_duration ~ .,
  data=training_data,
  num.trees = 10,
  mtry = 4
)

test_data$rf_predictions <- predict(rf_model, test_data)$predictions

## Calculate the R-Square for Random Forest
calc_rsquare(test_data$trip_duration, test_data$rf_predictions) # 0.6321241

## Root Mean Squared Error
rmse(test_data$rf_predictions, test_data$trip_duration) # 323.0989 seconds
323.0989/60 # 5.384982 (almost 1' difference from the lm)
 
## Visualize 
test_data_sample <- test_data %>% 
  sample_n(50000)

pred_plot <- ggplot(test_data_sample,
                    aes(x=trip_duration, y=lm_predictions)) +
  geom_point() + xlim(0, 4000)

pred_plot + geom_point(data = test_data_sample,
                    aes(x=trip_duration, y=rf_predictions),
                    color = "darkred") # Clearly a better fit


