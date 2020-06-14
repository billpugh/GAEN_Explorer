#  Controlled Experiments

This document describes how to perform controlled experiments in GAEN Explorer, and more generally controlled experiments of the Google Apple Exposure Notification framework.

The key element of a controlled experiment is that  there is a specific start and end time for the experiment, and you want to analyze the encounters detected by Bluetooth scans during just that time window, excluding any scanning that happens before or after that window. 

Anyone who wants to perform a controlled experiment of the exposure notification framework needs perform the following steps. GAEN Explorer automates much of this, but I want to explain it for the benifit of others trying to do experiments:
* Stop scanning: This can be done by either calling ENManager.setExposureNotificationEnabled(false), or by disabling the toggle for exposure logging in the Settings page for COVID-19 Exposure Logging.
* Delete information about previous scans. Do this by selecting the Delete Exposure Log  button at the bottom of the Settings page for COVID-19 Exposure Logging.
* Start scanning: You should try to do this on all devices participating the the experiment at the same time. This can be done by either calling ENManager.setExposureNotificationEnabled(true), or by disabling the toggle for exposure logging in the Settings page for COVID-19 Exposure Logging.
* Perform the measured portion of the experiment.
* Stop scanning: You should try to do this on all the devices participating the the experiment at the same time. 
* Exchange diagnosis keys
* Perform analysis. Important note: If exposure logging is disabled, calling ENManager.detectExposures will fail. But we don't want to introduce additional scan time into the analysis. GAEN Explorer turns on scanning immediately before running the analysis, and then turns it off immediately afterwards.
* Export analysis results




