# GAEN Explorer

This is code I wrote to explore and experiment with the Google+Apple Exposure Notification framework. It is intended to show how the framework can actually be invoked, and to testing of how the exposure detection system works. It is also the first non-trivial app I wrote in Swift. 

<p align="center"> 
<img src=“Documentation/screenShots/all.png” with=“80%”>
</p>

In particular, I wrote the code to figure out two things:
* the details of how things such as [ENExposureInfo.attenuationvalue ][1] is computed, which isn’t entirely clear from the documentation
* To do experiments where I could put two iPhones a specific distance apart for 20 minutes, then have the devices exchange diagnosis keys and see what they reported about the encounter
	* I also did more general experiments, where I installed the app on all of the iPhones in my household, and then exchanged keys every day to see who was reported as having close encounters with each other, and how that corresponded to our actual encounters. My kids were finishing up their college semester at home, and there were days when they were in crunch mode and we barely saw them


This app is not intended for use in alerting anyone to a diagnosis of COVID-19.

Rather than allowing people to report that they have been diagnosed with COVID-19 and having diagnosis keys distributed by a diagnosis key service, the system allows diagnosis keys to be shared between two devices by email or airdrop. When the keys are received, they are immediately processed and the exposes are recorded. 

You must have the special entitlements that Apple is giving out in order to be able to run this code, and they are only giving out those entitlements to developers working with public health organizations. Several important notes:
* I can't help you get those entitlements. 
* The app uses a special entitlement that allows it to get the diagnosis key for the current day.
* The encounter notification framework will only run on actual devices, not in the simulator. 

Some code was taken from the sample Encounter Notification app [provided by Apple][2], in particular the code for computing the signing files for the keys. 

[1]:	https://developer.apple.com/documentation/exposurenotification/enexposureinfo/3583712-attenuationvalue
[2]:	https://developer.apple.com/documentation/exposurenotification/building_an_app_to_notify_users_of_covid-19_exposure
