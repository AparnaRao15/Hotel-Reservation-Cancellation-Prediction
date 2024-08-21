/****************
Name: Aparna Raghavendra Rao
Project: Hotel Cancellation Prediction
****************/


/*IMPORT & VIEW DATA*/
libname Project '/home/u63865871';

proc import datafile='/home/u63865871/Hotel Reservations 2 - modified  names.csv'
out=Project.hotel_cancellations
dbms=csv
replace;
	getnames=yes;
run;

/*EXPLORATORY DATA ANALYSIS*/
/*check the variables in the dataset*/
proc contents data=Project.hotel_cancellations;
run;

/*check the averages*/
proc means data=Project.hotel_cancellations;
run;

/*check for missing values*/
proc means data=Project.hotel_cancellations nmiss;
run;

/*drop the booking_id column*/
data Project.EDA_data;
	set Project.hotel_cancellations;
	drop booking_id;
run;

/*target variable distribution*/
proc sgplot data=Project.EDA_data;
	title "Target variable distribution";
	label booking_status="Booking Status";
	vbar booking_status;
run;

/*Most popular meal plan*/
proc sgplot data=Project.EDA_data;
	title "Most popular meal plan";
	vbar type_of_meal_plan;
	label type_of_meal_plan="Type of Meal Plan";
run;

/*Most popular type of room reserved*/
proc sgplot data=Project.EDA_data;
	title "Most popular room type";
	vbar room_type_reserved;
	label room_type_reserved="Room Type Reserved";
run;

/*Most frequently occuring market segment*/
proc sgplot data=Project.EDA_data;
	hbar market_segment_type;
	label market_segment_type="Market Segment Type";
	title "Most popular method of booking";
run;

/*Number of repeating guests*/
proc sgplot data=Project.EDA_data;
	title "Number of repeating guests";
	vbar repeated_guest;
	label repeated_guest="Repeated Guests";
run;

/*Number of previous cancellations*/
proc sgplot data=Project.EDA_data;
	title "Number of previous cancellations";
	vbar no_of_cancellations;
	label no_of_cancellations="No of Previous Cancellations";
run;

/*EXPLORATORY DATA ANALYSIS - VISUALIZATION*/

/*set colors for cancellations  and non-cancellations*/
data myattrmap;
length value $15 linecolor $ 9 fillcolor $ 9;
input ID $ value $ linecolor $ fillcolor $;
datalines;
myid Canceled maroon maroon
myid Not_Canceled gray gray
;
run;

/*During which months do cancellations occur the most*/
proc sgplot data=Project.eda_data dattrmap=myattrmap;
	vbar arrival_month / group=booking_status groupdisplay=cluster attrid=myid;
	label arrival_month="Arrival Month"
		  booking_status="Booking Status";
	title "Monthly Cancellations and Non-Cancellations";
run;

/*which month has the highest average monthly room price*/
proc sql;
	create table avgMonthlyPrice as
	select arrival_month, mean(avg_price_per_room) as avg_monthly_price
	from Project.eda_data
	group by arrival_month
	order by arrival_month
;

proc sgplot data=avgMonthlyPrice;
	series x=arrival_month  y=avg_monthly_price;
	title "Average Monthly Room Price";
	xaxis type=discrete;
	label arrival_month="Arrival Month"
		  avg_monthly_price="Average Monthly Price";
run;

/*Does lead time influence cancellations?*/
proc freq data=Project.eda_data;
	tables lead_time*booking_status / out=freq_data;
run;

proc sgplot data=freq_data dattrmap=myattrmap;
	series x=lead_time y=COUNT / group=booking_status attrid=myid;
	label lead_time="Lead Time"
		  booking_status="Booking Status";	
	title "Cancellations and Non-Cancellations according to Lead Time";
run;

/*Does the average price of a room influence cancellations*/
proc freq data=Project.eda_data;
	tables avg_price_per_room*booking_status / out=freq_data2;
run; 

proc sgplot data=freq_data2 (where=(booking_status='Canceled')) dattrmap=myattrmap;
	series x=avg_price_per_room y=COUNT / group=booking_status attrid=myid;
	label booking_status="Booking Status"
		  avg_price_per_room="Average Price per Room";
	title "Average Room Price and Cancellations";
run; 

/*Assign colors for scatterplot*/
data myattrmap2;
length value $15 linecolor $ 9 fillcolor $ 9;
input ID $ value  markersymbol : $20.  markercolor : $20.;
datalines;
myid Canceled circlefilled maroon
myid Not_Canceled circlefilled gray
;
run;

/*Does lead time and average price per room affect cancellations?*/
proc sgplot data=Project.eda_data dattrmap=myattrmap2;
	scatter x=lead_time y=avg_price_per_room / group=booking_status attrid=myid;
	label lead_time="Lead Time"
		  avg_price_per_room="Average Price per Room"
		  booking_status="Booking Status";
	title "Lead time and Average Room Price Impact on Cancellations";
run;

/*ANALYSIS*/

/*train-test split*/
/*simple random sampling*/
proc surveyselect data=Project.hotel_cancellations rate=0.70 outall out=Project.analysis_data seed=1234;
run;

data hotel_train1 hotel_test1;
	set Project.analysis_data;
	if selected =1 then output hotel_train1;
	else output hotel_test1;
	drop selected;
run;

proc freq data=hotel_train1;
table booking_status;
run;

proc freq data=hotel_test1;
table booking_status;
run;

/*stratified sampling*/
/*helps balance imbalanced datasets*/
proc sort data=Project.hotel_cancellations out=Project.analysis;
by booking_status;
run;

proc surveyselect data=Project.analysis rate=0.70 outall out=Project.analysis_data2 seed=1234;
strata booking_status;
run;

data hotel_train hotel_test;
	set Project.analysis_data2;
	if selected=1 then output hotel_train;
	else output hotel_test;
	drop selected;
run;

proc freq data=hotel_train; 
table booking_status; 
run;

proc freq data=hotel_test;
table booking_status;
run;

/*MODELLING*/

/*Logistic Regression Model*/
proc logistic  data=hotel_train outmodel=model_train;
	class type_of_meal_plan room_type_reserved market_segment_type booking_status;
	model booking_status(event='Canceled') = no_of_adults 
								  no_of_children 
								  no_of_weekend_nights 
								  no_of_week_nights
								  type_of_meal_plan
								  req_car_space
								  room_type_reserved
								  lead_time
								  arrival_year
								  arrival_month
								  arrival_date
								  market_segment_type
								  repeated_guest
								  no_of_cancellations
								  no_of_noncancellations
								  avg_price_per_room
							 	  no_of_special_requests
 / 
	selection=stepwise
	details
	lackfit;
	score data=hotel_test  out=score1;
	store log_model;
run;

/*Score models*/
/*training data*/
proc logistic  inmodel=model_train;
	score data=hotel_train out=score2 fitstat;
run;

/*test data*/
proc logistic inmodel=model_train;
	score data=hotel_test  out=score3 fitstat;
run;

/*Confusion Matrix*/
/*training confusion matrix*/
proc freq data=score2;
	tables f_booking_status*i_booking_status / nocol norow;
run;

/*test confusion matrix*/
proc freq data=score3;
	tables f_booking_status*i_booking_status / nocol norow;
run;

/*predictions file for end user usage*/
proc export data=hotel_test
file="/home/u63865871/Results.csv" replace;
run;