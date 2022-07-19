;Noe, Nusrat, Alina
;COVID Simulation on college campus

;========================= GLOBAL AND INSTANCE VARIABLES =========================
globals[
  max-recovery
  transmission-rate
  infection-count
  reported-cases
  day-count
  hour-count
]

breed[students student]

patches-own[
  party-dorm?            ; dorms pertaining to each type of student
  quiet-dorm?
  mixed-dorm?
  CS-building?
  dining-hall?
  testing-site?
  isolation-housing?
]

students-own[
  partier?                ; is the student a partier?
  quiet?                  ; is the student quiet?
  mixed?                  ; is the student somewhere in the middle?
  A-block                 ; these are attributes pertaining to the student's schedule
  B-block
  vaccinated?
  mask-on?
  infected?
  positive-test?
  negative-test?
  unknown?                ; is the student positive but has not been tested
  remaining-recovery
]

;================================================== INITIAL SETUP ==================================================
;-- All of the procedures in our Initial Setup section are in Observer context
; These functions initialize our simulation, drawing the map and creating our student body
;** None of these functions take in parameters**

;Setup procedure
;Draws the theoretical campus map, initializing dorms, one dining hall, and 75 Shannon St
;Initializes students based on num-students slider in the interface, also initializes infections
to setup
  ;reset ticks
  ca
  reset-day
  import-pcolors "Pandemic Map-1 2.png"
  crt-students

  ;create campus map
  set-buildings
  set-testing-site
  set-isolation-housing
  set-labels

  ;set infcection globals
  set infection-count init-infected
  set reported-cases 0
  set max-recovery 7                                             ;max recovery is set to 7, meaning students isolate for 7 days
  set transmission-rate 100
  set-blocks                                                     ;assigns each student to a sheduling block

end

;GO procedure
;Handles the running of the simulation, if the infection percentage gets too high, the simulation will be halted
;Calls the structure-day function that pertains to student schedule
to go
  ;If percentage of covid reaches 75, our simulation will halt
  if covid-percent >= 75 [
    ask students [die]
    ask patches [set pcolor black  ]
    ask patch (max-pxcor / 2 + 200) (max-pycor / 2) [
      set plabel "Simulation has been halted - Percentage of students with COVID has reached 75"
      set plabel-color white
    ]
  ]
  structure-day
end

;CLOCK procedure:
; -- resets clock after 24 hours
; -- adds to hour count
to clock
  tick
  set hour-count hour-count + 1
  if hour-count = 25 [
    set hour-count 0
    set day-count day-count + 1
  ]
  wait 0.1
end

; ----------------------------- MAP SETUP -----------------------------
;Procedure to set "buildings" patches -- depending on the color of patches, the area is set to a boolean building value
to set-buildings
  ask patches[
    if pcolor = 5.4 [set CS-building? true]

    if pcolor = 94.9 [set party-dorm? true]

    if pcolor = 25.7 [set quiet-dorm? true]

    if pcolor = 125.4 [set mixed-dorm? true]

    if pcolor = 34.5 [set dining-hall? true]
  ]
end

;Setup procedure for testing site
to set-testing-site
  ask patches with [pxcor > 300 and pycor > 50 and pycor < 110][
    set pcolor black
    set testing-site? true
  ]
end
;Setup procedure for isolation housing
to set-isolation-housing
  ask patches with [pxcor < 100 and pycor > 50 and pycor < 110][
    set pcolor pink
    set isolation-housing? true
  ]
end

; Procedure to set labels for each building, placed on a specific pxcor and pycor
to set-labels
  ask patches [set plabel-color black]

  ask patch 265 220[ set plabel "75 Shannon St."]

  ask patch 250 550[ set plabel "Quiet Dorm"]

  ask patch 140 550 [ set plabel "Party Dorm"]

  ask patch 370 550 [set plabel "Mixed Dorm"]

  ask patch 250 360 [ set plabel "Dining Hall"]

  ask patch 400 120 [set plabel "Testing Site"]

  ask patch 90 120 [set plabel "Isolation Housing"]

end
;----------------------------- STUDENT (turtle) SETUP -----------------------------
;Procedure to assign student attributes
;These attributes are initialized to ALL students after creation (universally applicable)
;Mask optional switch in interface determines whether students are initialized with mask-on or mask-off
to student-attributes
    set positive-test? false
    set color green
    set shape "person student"
    set size 10
    setxy random-xcor random-ycor
    set positive-test? false
  ifelse mask-optional? [set mask-on? false][set mask-on? true]
end

;Procedure to create students
;Students have been divided into one of 3 categories, determining their behavior
;These categories are quiet, partier, or mixed (somewhere in-between)
;this procedure assigns them to one of the three attributes
to crt-students
  ;creates party students
  create-students num-students / 3 [
    student-attributes
    set partier? true
    set quiet? false
    set mixed? false
  ]
  ;creates quiet students
  create-students num-students / 3 [
    student-attributes
    set quiet? true
    set partier? false
    set mixed? false
  ]

  ;creates social students (in between quiet and partier)
  create-students num-students / 3 [
    student-attributes
    set mixed? true
    set quiet? false
    set partier? false
  ]

  ;if there is a remainder of students, they are assigned to mixed
  if num-students mod 3 != 0[
    let remainder-students num-students - count students
    create-students remainder-students[
      student-attributes
      set mixed? true
      set quiet? false
      set partier? false
    ]
  ]

  ;calls vaccination status function
  set-vaccination-status
  ;initializes infections
  init-infections
end

;Procedure to set the vaccination status of students
;Vaccination status of student is random, based on vaccination rate slider in the interface
to set-vaccination-status
  let num-vax int(count students * vaccination-rate / 100)
  ask n-of num-vax students[
    set vaccinated? true
  ]
  ask students[
    if vaccinated? = 0[
      set vaccinated? false
    ]
  ]
end

;Procedure to initialize infections based on slider in the interface, init-infections
;Random students are initialized with COVID, their attributes (quiet, party, mixed) do not matter
;All students initially infected are unknown, meaning they have not been tested
to init-infections
  ask n-of init-infected students[
    set infected? true

    set unknown? true                                          ;color of students is yellow when infection is present but unknown
    set color yellow
  ]
end

;Procecure to apply a certain schedule to students -- creates an A block an B block to determine when the students eat and go to class
;Students are assigned randomly to blocks
to set-blocks
  ask n-of int(num-students / 2) students [
    set A-block true
    set B-block false
  ]
  ask students with [A-block != true][
    set B-block true
    set B-block false
  ]
end

;================================================== MOVEMENTS =========================================================
;**** ALL Procedures in the "Movements" section operate in TURTLE CONTEXT *****
;No procedures in this section take in parameters
;This section simulates movement across campus by students, according to their respective behaviors

;Procedure to structure the day of each student
;Behavior of students is dependent on the hour of the day
to structure-day
  ;Sleeping
  if hour >= 0 and hour < 7[                                     ; When hour is between 0 and 7, the students are sleeping
    ask students [go-home]
  ]
  ;Once per day testing
  ifelse test-frequency = "once per day"  [                      ; IF our simulation tests students once per day, they are tested at 7am
    if hour = 7[
      show hour
      ask students [go-testing isolate]                          ; testing procedure is called, as well as isolate procedure for those who test positive
    ]
  ]
  ;once per week testing                                         ; IF our our simulation tests students once per week,
  [                                                              ; we wait to test until day = 7 and hour =7
    if day = 7 and hour = 7 [
      ask students [go-testing isolate]                          ; testing and isolation procedures called again
    ]
  ]
  ;class and eat time
  if hour >= 8 and hour < 16 [                                   ; When hour is between 8 and 16, students either go to class or go eat
    ask students [                                               ; ** activity is dependent on block assignment **
      block-schedule
      transmit-covid
    ]
  ]
  ;free time
  if hour >= 16 and hour <= 24 [                                 ; When hour is between 16 and 24, students have free time
    ask students [                                               ; free time activities are dependent on a student's behavior
      go-free-time
      transmit-covid
    ]
  ]
  clock                                                          ; clock procedure called
end

;Procedure to send students back to respective dorm -- dorms are labeled depending on which students the house
;Spacing (social distancing) element to the quiet dorm, students are ensured to be on separate patches
to go-home
  if positive-test? != true[
    if partier? = true [
      move-to one-of patches with [party-dorm? = true]
    ]
    if quiet? = true[
      move-to one-of patches with [quiet-dorm? = true]
      ; this allows for some potential spacing out in quiet dorm
      if any? other students in-radius (0.5 + random 1) [
        move-to one-of other patches with [quiet-dorm? = true]
      ]
    ]
    if mixed? = true[
      move-to one-of patches with [mixed-dorm? = true]
    ]
  ]
end

;Procedure that sends students to building labeled, 75 Shannon St.
;All students have their mask on while attending class, regardless of the mask-optional switch
;Only students that don't have a positive test go to class
to go-class
  if positive-test? != true[
    set mask-on? true
    move-to one-of patches with [CS-building? = true]
  ]
end

;Sends students without a positive test to dining hall
;While they are inside, their mask is off, regardless of mask-optional switch (to simulate eating)
to go-eat
  if positive-test? != true[
    set mask-on? false
    move-to one-of patches with [dining-hall? = true]
  ]
end

;Procedure to simulate student free time
;Depending on a student's attribute, their free time looks very different
;Partiers go to their dorm, without their mask, and socialize
;Mixed students either go party or to their own dorm --- mask status of these students is random
;Quiet students go to their dorm with masks on
to go-free-time
  if positive-test? != true [
    if partier? = true [
      set mask-on? false
      move-to one-of patches with [party-dorm? = true]
    ]
    ;creating more variablity for the mixed students' free time
    if mixed? = true [
      ifelse random-float 1 < 0.5 [                                          ; Mask could be on or off
      set mask-on? false
      ][
        set mask-on? true
      ]
      move-to one-of patches with [party-dorm? = true or mixed-dorm? = true]  ; move to either their home or party dorm
    ]
    if quiet? = true [
      set mask-on? true                                                       ;Quiet kids have mask on in free time
      go-home
    ]
  ]
end

;Creates a schedule for a random network of students
;Block A and B have different class / eat times
to block-schedule
  ;block A kids
  ifelse A-block = true[
    if hour >= 8 and hour < 12[ go-eat ]
    if hour >= 12 and hour < 16[ go-class ]
  ]
  ;block B kids
  [
    if hour >= 8 and hour < 12[ go-class ]
    if hour >= 12 and hour < 16[ go-eat ]
  ]
end


;;================================================== COVID TESTING =========================================================
;Simulates campus selection for testing, testing, and isolation.
;Switch in interface determines whether testing is "Dynamic" or Mandatory"
; -- dynamic testing selects a random population of students to get tested
; -- mandatory testing requires that all students to test
;After selecting and moving students, test procedure is called
to go-testing
  ;Mandatory testing
  if testing-type = "Mandatory Testing" [
    if positive-test? != true[                                                ;ensures that student does not already have a positive test
      move-to one-of patches with [testing-site? = true]
      test
    ]
  ]
  ;Dynamic testing
  if testing-type = "Dynamic Testing"
  [
    if positive-test? != true [                                                ;ensures that student does not already have a positive test
      ;tests about half of the students
      if random-float 1 < 0.5[                                                 ;students to test are selected randomly
        ; dynamic testing
        move-to one-of patches with [testing-site? = true]
        test
      ]
    ]
  ]
end

;Procedure to update instance variables and globals while testing
;if positive test, student's color turns red, their remaining recovery variable is set to max recovery,
;and the infection count increases
to test
  ifelse infected? = true [                                                    ;if student is infected -- upadate variables
    set positive-test? true
    set negative-test? false
    set unknown? false
    set remaining-recovery max-recovery                                        ;max-recovery variable is set to 7 (one week)
    set color red                                                              ;if student gets a positive test -- they turn red
    set infection-count infection-count + 1
    set reported-cases reported-cases + 1
    move-to one-of patches with [isolation-housing? = true]
  ][
    set positive-test? false                                                   ;student gets negative test
    set negative-test? true
    set unknown? false
  ]
end

;Procedure to send students with a positive test to isolation housing
;Students in isolation housing will isolate for 7 days
;When done isolating, the students have overcome the infection and get sent home
;turtle context
to isolate
  if positive-test? = true[
    if hour = 24[
      set remaining-recovery remaining-recovery - 1
    ]

    if remaining-recovery = 0[
      set positive-test? false
      set infected? false
      set infection-count infection-count - 1
      go-home
    ]
  ]
end

;;================================================== COVID TRANSMISSION =========================================================
;These are all procedures pertaining to the transmission and spread of COVID around the campus. All procedures in this section
;are in turtle context. None of these procedures take in parameters.

;Procedure to call the spread of COVID on individual agents
; this is essentially a "getter" function
to transmit-covid
  if infected? = true[ spread ]
end

;Procedure to spread COVID -- transmission rates are from the official CDC website
;If a positive stuent is within a certain cone of another student, they will have a certain probability of spreading COVID to that student
;There are several circumstances that affect the probability of COVID being transmitted (we use a combination of these factors):
;   1) is the student's mask on?
;   2) is the student vaccinated?
;if covid is spread --> update-status procedure is called
to spread
  ask other turtles in-cone 5 90 with [infected? = 0][                          ;OTHER students in-cone 5 90
    if not mask-on? and not vaccinated?[
      ;50% transmission rate
      if random-float 100 < transmission-rate[ update-status ]                  ;does that other student NOT have mask on and NOT vaccinated? (50% transmission rate)
    ]
    if mask-on? and not vaccinated?[
      ;38% transmission rate
      if random-float 130 < transmission-rate[ update-status ]                  ;does that other student HAVE mask on but is NOT vaccinated? (38% transmission rate)
    ]
    if not mask-on? and  vaccinated?[
      ;15% transmission rate
      if random-float 350 < transmission-rate[ update-status ]                  ;does that other student NOT have mask on but IS vaccinated? (15% transmission rate)
    ]
    if  mask-on? and  vaccinated?[
      ;11% transmission rate
      if random-float 450 < transmission-rate[ update-status ]                  ;does that other student HAVE mask on and IS vaccinated? (50% transmission rate)
    ]

  ]
end

;Procedure to update the instance and global varialbes of student who get COVID
;their infected attribute is true, but their infection is unknown
;their color is set to yellow
;Infection count increases
to update-status
  set infected? true
  set unknown? true
  set remaining-recovery max-recovery
  set size 20
  set color yellow
  set infection-count infection-count + 1
end

;;================================================== REPORTERS =========================================================
;This section is a list of reporters that aid in the functionality of the simulation's interface
; Most of these reporters are linked to monitors

;reports % total cases
to-report covid-percent
  let percent-infected (infection-count / num-students) * 100
  report percent-infected
end

;reports unreported cases
to-report unreported-positive
  let unreported (count students with [infected? = true] - reported-cases )
  report unreported
end

;reports tested positive cases
to-report tested-cases
  report reported-cases
end

;reports the current day
to-report day
  report day-count
end

;reports the hour
to-report hour
  report hour-count
end

;-- Part of setup seciton
; resets the day according to ticks
to reset-day
  reset-ticks
  set day-count 0
  set hour-count 0
end


;======CHALLENGE IF WE HAVE TIME ======
;Procedure to implement contact network
to close-contacts
  ask students [
    if count link-neighbors = 0 [;if they don't have a group yet
                                 ;ask 3 other students who don't have a group yet
                                 ;there will be a remainder of students without a group but that's fine
      repeat 3[
        ask min-one-of other students with [count link-neighbors = 0] [distance myself][
          create-link-with myself
        ]
      ]
    ]

  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
669
620
-1
-1
1.0
1
10
1
1
1
0
0
0
1
0
450
0
600
0
0
1
ticks
30.0

BUTTON
79
312
134
345
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
29
112
201
145
vaccination-rate
vaccination-rate
0
100
90.0
5
1
%
HORIZONTAL

SLIDER
27
27
199
60
num-students
num-students
0
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
27
68
199
101
init-infected
init-infected
0
10
8.0
1
1
NIL
HORIZONTAL

PLOT
710
16
910
166
Covid-Dashboard
days
positive-cases
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [infected? = true]"

MONITOR
715
269
848
314
Percent Infected (%)
covid-percent
3
1
11

BUTTON
78
354
133
387
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
713
196
772
241
NIL
day
17
1
11

MONITOR
783
196
841
241
NIL
hour
17
1
11

CHOOSER
44
207
183
252
test-frequency
test-frequency
"once per day" "once per week"
0

CHOOSER
44
258
184
303
testing-type
testing-type
"Mandatory Testing" "Dynamic Testing"
1

SWITCH
30
157
199
190
mask-optional?
mask-optional?
1
1
-1000

MONITOR
716
392
827
437
Reported Cases
tested-cases
17
1
11

MONITOR
715
327
840
372
Unreported Cases
unreported-positive
17
1
11

@#$#@#$#@
## WHAT IS IT?

COVID Simulation on a college campus. The model is capable of using previously implemented Middlebury College COVID guidelines to simulate vairous test plans.

## HOW IT WORKS

Within the COVID model, a campus environemnt is generated and labeled by using patches-own to designate portions of the plane as a type of building/environment. A turtle breed called 'students' is used as a representation of a single student. 

Students are provided with various students-own booleans/variables that determine their own behaviour, and ensures that there can be as much individualized behaviour as possible. Most notably, students' behaviour can be classified by both their block and student-type. Students' individual behaviour is determined by a randomly assigned student-type of either being a 'pariter', a 'quiet', or a 'mixed' -- 'mixed' being a mixture of both partiers and quiet students -- student-type. The randomly assigned student-type determines their designated dorm, whererin the 'party' dorm sees more 'party' activity. The block boolean then splits students into either an A or a B block, which is meant to simulate a schedule-like day. This was implemented in order to have a randomly assigned half of the student body have meals, while the other half attends class. 

The model operates over time, through the usage of ticks. Each tick represents one hour, and each hour determines the bevahior of the students. Between hours 0 and 8, students are sleeping. Between hours 8 and 16, students are attending class and eating (order pertaining to scheduling blocks). Finally, between hours 16 and 24, students are in their 'free-teim', which looks different depending on the student. 'partiers' party in their free time, while quiet students return to their dorm. Mixed students do some of both. 

The remaining students-own booleans and variables are used to simulate transmissions, as well as a generalized campus life, wherein campus life can be simulated using Choosers to determine the state of campus in terms of COVID precautions. Each COVID precaution option is based on Middlebury College's own COVID guidelines, wherein we have had mask-optional or mandatory masking, and either mandatory all-student testing, or dynamic randomly selected student testing. 

Patch location is used depending on the location and color of the imported map. Patches-own is used to label or categorize portions of the map by what their intended purpose is.

## HOW TO USE IT

Use all non-button options to the left of the plane to define initial model conditions. Once all options have been selected, the 'setup' button is selected in order to create the model environment. The 'go' button is then selected to simulate the model.

The model simulates using the selected conditions until there is too large of a COVID outbreak, defined by >75% of the student body becoming infected. As long as the percent of infected students remains below the given threshold, the model will continue to simulate.

To the right of the model plane, plots and monitors are provided to monitor the model in real-time. A large plot simulates the total current count of positive cases based on how many days have passes. 'Day' and 'hour' reporters display the current day number, begining at 1, and the current hour for each day. The 'hour' counter keeps track of the current time within a given day, and goes up until 23. The remaining reporters are used to keep track of current COVID spread within the student body. 

## THINGS TO NOTICE

Observe how the spread of COVID may be faster or slower depending on factors such as vaccination rate or mask-policies. 

The current model simulates at a slower than expected time. This is likely as a result of the provided code consistently using ask turtles[] statements, and as NetLogo prrocesses each turtle one by one, it simulates at slower rates when ask turtles[] statements are used. 

## THINGS TO TRY

Try to minimize the spread of COVID in a pre-vaccine environment, meaning lower vaccination rates.

Try to minimize the spread of COVID in a post-vaccine and more relaxed environment, meaning infrequent testing and relaxed mask-policies. 
(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

Introducing outside factors into the model would provide a more realistic simulation. The current simulation, in the most COVID relaxed scenario assumes a campus bubble, with limited to no travel outside of campus. 

Implementing inner-campus mobility restrictions may be another way to determine how student-behavior impacts the spread of COVID. One of Middlebury's precautionary policies was the restriction of entering dormitaries that were not one's own. 

Through the creation of our scheduling blocks, we have begun to investigate the idea of contact networks. If given more time to do so, contact networks would be fully implemented and functioning.

A larger student body would likely also generate more reliable data, but in doing so a much slower model would have been generated.

## NETLOGO FEATURES

In order to generate a campus setting, a hand-drawn simplified campus was uploaded and pcolor was manually determined and used to create buildings using patches-own booleans.

For COVID transmissions, we understood that COVID is spread not by radius but by cone dirrection, meaning that only if an infected individual is facing in your direction can one become infected. To simulate this, the in-cone feature was used and transmission was dependant on an agent's heading.

The Behavior Space mode was used to run repititions of models with desired conditions, and it outputted a .csv spreadsheet file that summarized and informed the data provided in the 'MODEL EXPERIMENT' section.

## MODEL EXPERIMENT

We used the behavior space experimentation feature in NetLogo to quantify the observations that we have collected throughout building the model. Specifically, the purpose of our experiment was to determine the effect of testing frequency on the spread of the virus. Our experiment’s parameters were: 100 students, mask-optional = false (meaning masks were mandatory in indoor spaces), and dynamic testing (meaning a random population of students are tested each week), as well as a 0% vaccination rate to simulate a pre-vaccine campus environment. With these baseline conditions, we tested how many ticks it took the model to produce 75% infection, with once per day testing v.s. once per week testing. The experiment results supported our hypothesis that once per day testing caused a slower spread of the virus, vs. once per week testing. Once per day testing yielded an average duration of 131.8 hours, or ticks, for the model simulation. Once per week testing, on the other hand, yielded a lower average duration of  127.8 hours, or ticks, for the model simulation. 

A shortcoming of this experiment is that there is only a difference of around 10 ticks between the two observed averages, suggesting that the specifics of our model need some adjusting to simulate a more real-world model.

## CREDITS AND REFERENCES

Citations: 
Kerr, Cliff C., et al. “Covasim: An Agent-Based Model of COVID-19 Dynamics and Interventions.” 2020, https://doi.org/10.1101/2020.05.10.20097469. 

National Institutes of Health, U.S. Department of Health and Human Services, https://covid19.nih.gov/. 

“Scientific Brief: SARS-COV-2 Transmission.” Centers for Disease Control and Prevention, Centers for Disease Control and Prevention, https://www.cdc.gov/coronavirus/2019-ncov/science/science-briefs/sars-cov-2-transmission.html. 

Truszkowska, Agnieszka, et al. “Covid‐19 Modeling: High‐Resolution Agent‐Based Modeling of Covid‐19 Spreading in a Small Town (Adv. Theory Simul. 3/2021).” Advanced Theory and Simulations, vol. 4, no. 3, 2021, p. 2170005., https://doi.org/10.1002/adts.202170005. 

The National Institues of Health (NIH) and Center for Disease Control (CDC) COVID-19 websites were of tremendous aid throughout this project. These sources are how we accessed data to influence the transmission of the virus within our model. Specifically, we found the distinct transmission rates, dependent on variables like masking and vaccination, in order to construct transmission probabilities between students. Additionally, we were able to calculate the distance needed between two agents in order to transmit the virus. 

The two scientific papers presented in class were extremely helpful in designing the organization, scope, and communication of the model. Many of our variables in the interface were influenced by features that these models contain. In addition, the idea of studnet organization through scheduling blocks came from the contact networks in these models. In particular, the study of COVID-19 in a small town environment was helpful to conceptualize the spacial scale of our model.

On this assignment, our group received assistance from Rebecca Warholic (ASI) and Professor Matthew Dickerson.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person farmer
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 60 195 90 210 114 154 120 195 180 195 187 157 210 210 240 195 195 90 165 90 150 105 150 150 135 90 105 90
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -13345367 true false 120 90 120 180 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 180 90 172 89 165 135 135 135 127 90
Polygon -6459832 true false 116 4 113 21 71 33 71 40 109 48 117 34 144 27 180 26 188 36 224 23 222 14 178 16 167 0
Line -16777216 false 225 90 270 90
Line -16777216 false 225 15 225 90
Line -16777216 false 270 15 270 90
Line -16777216 false 247 15 247 90
Rectangle -6459832 true false 240 90 255 300

person student
false
0
Polygon -13791810 true false 135 90 150 105 135 165 150 180 165 165 150 105 165 90
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 100 210 130 225 145 165 85 135 63 189
Polygon -13791810 true false 90 210 120 225 135 165 67 130 53 189
Polygon -1 true false 120 224 131 225 124 210
Line -16777216 false 139 168 126 225
Line -16777216 false 140 167 76 136
Polygon -7500403 true true 105 90 60 195 90 210 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Mask Efficacy" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="168"/>
    <exitCondition>covid-percent = 75</exitCondition>
    <metric>count turtles with [infected? = true]</metric>
    <metric>day-count</metric>
    <metric>hour-count</metric>
    <enumeratedValueSet variable="test-frequency">
      <value value="&quot;once per week&quot;"/>
      <value value="&quot;once per day&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-infected">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-optional?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vaccination-rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="testing-type">
      <value value="&quot;Dynamic Testing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-students">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
