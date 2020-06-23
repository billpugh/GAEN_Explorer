#  Multipeer experiment

Every device has to provide a user name before they can participate in multipeer experiments. 

Initially, everyone is in advertise mode when they go to the multipeer experiment page

If an user goes to multipeer experiment page and no one is hosting, they are asked if they want to become host. Wait 10 seconds to see if they get invited before offering to host.


The existing diagnosis description is sent to each participant as they join. When it is modified, it is sent to everyone.
* message design (description, duration)

ll participants are asked to erase their exposure log and get their diagnosis keys (if they are not retained).  When they have done that, they signal that they are ready to everyone else, and to new participants
* message ready (key, numParticipants)

The host can start the experiment
* message startExperiment (startAt, endAt)


The multipeer screen shows a list of all participants, and whether they are ready

When everyone is ready, the host can send out a start experiment message, with a start and end date for the experiment. The start data should be about 20 seconds in the future. 

When the experiment starts, all multipeer advertising and broadcasting stops. 

The app schedules a local notification for when the end date occurs, and creates a background task to turn on scanning when the experiment begins.



