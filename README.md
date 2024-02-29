TERRA (Top-down Emission Rate Retrieval Algorithm)

written by Andrea Darlington, ECCC

Calculates the emission rate of a pollutant or the flux of the pollutant through a screen. 
This repo contains the files needed to setup TERRA with new flights.  The TERRA_User repo (which is a submodule of this repo) contains the code and instructions to run TERRA once the flights have been setup: https://github.com/ARQPDataTeam/TERRA_User

![](/TERRA.jpg)

## Install Requirements
You must install git to install TERRA.  This can be done by downloading the file here and running the installation (leave all options in the installer as the default):
https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/Git-2.44.0-64-bit.exe

## Installing TERRA
TERRA can be installed by running the TERRAInstall.cmd file located here (for ECCC users):
\\econl0lwpfsp001.ncr.int.ec.gc.ca\arqp_data\Resources\Software\Windows\Igor\Tool_Installers\
And in this repo for external users.

Ensure that all instances of Igor have been closed before running the installation file and if you encounter any errors please contact a member of the Data team at Équipe de données / Data Team (ECCC) equipededonnees-datateam@ec.gc.ca to assist with installation. 
Once installation is complete, open Igor Pro and choose Load TERRA from the Analysis menu.  TERRA will check for updates upon loading into an experiment file.  If any are available, they will be updated at this time.

## Instructions for Use
Instructions for setting up flights for TERRA are available in the TERRA_Setup... word documents.  Instructions for using TERRA on existing flights are available in the TERRA Instructions.docx file within the TERRA_User submodule folder.

## Updating this Repo - For Developers Only
This repo is connected to the TERRA_User repo (it is a submodule of this one).  When updates are made to TERRA_User, it is necessary to update this repo using the command:
git submodule update --remote --merge
Then follow normal procedures to commit and push this update within TERRA_Setup.
