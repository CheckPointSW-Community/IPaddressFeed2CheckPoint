# IPaddressFeed2CheckPointAPI
Adding an IP Address feed (CIDR) into Checkpoint Objects (here Office 365)

How to use:

1. Copy the o365-address_update.sh to Check Point Management Server

    Example: 
    mkdir -p /var/scripts/o365

    copy o365-address_update.sh to above directory


2. Edit the o365-address_update.sh script to define variables for your enviroment

    a. Directory under “v_spath”

        Example: 
        v_spath=/var/scripts/o365


    b. Edit the script by uncommenting your Check Point Management Server version


        Example: 
        #If this machine version R80.40, uncomment the line below
        source /opt/CPshrd-R80.40/tmp/.CPprofile.sh
        #If this machine version R80.30, uncomment the line below
        #source /opt/CPshrd-R80.30/tmp/.CPprofile.sh
        #If this machine version R80.20, uncomment the next line
        #source /opt/CPshrd-R80.20/tmp/.CPprofile.sh
        #If this machine version R80.10, uncomment the line below
        #source /opt/CPshrd-R80/tmp/.CPprofile.sh

    c. Define variables for your enviroment

        Example: 
        #Policy Name
        v_polpack=Standard
        #Policy Target Name
        v_poltarget=ledinfrfw01
        #Name of group object
        v_grp=ge_o365-networks
        #Naming prefix for elements
        v_objprefix=net-o365-
        #comment for objects
        v_objcomment="Do NOT use this object. Automatically created and deleted!"
        #color of objects
        v_objcolor=yellow
        #Login User
        v_cpuser=apiuser
        #Login Password
        v_cpuserpw=changeme

3. Cron job to check updates to ip address list

    In GAiA Web UI just add Job Schedule for this
    
    Example:
    sh /var/scripts/o365/o365-address_update.sh | /usr/bin/tee -a /var/scripts/o365/o365_logging 2>&1 | /usr/sbin/sendmail --domain=(mail domain) -f (sender address) -v (recipient address) --host= (mail relay) 2>&1

    Adds logging entries to a file "o365_logging" and sending a mail with the content


4. Adapting to other feeds

    The script can be used for any other feeds, where network addresses are in CIDR format. As the script already does a diff between existing objects and those downloaded, the full list should be used. Objects are automatically removed from the group and from Check Point Management Server when they are not part of the feed.

5. Feeds

    [Office 365 URLs and IP address range](https://endpoints.office.com/endpoints/worldwide?noipv6&ClientRequestId=b10c5ed1-bad1-445f-b386-b919946339a7)

6. Additional Information

    [This script is referenced in Check Point SK167000](https://supportcenter.checkpoint.com/supportcenter/portal?eventSubmit_doGoviewsolutiondetails=&solutionid=sk167000)

    [Originally cloned from the API project written by leinadred](https://github.com/leinadred/IPaddressFeed2CheckPointAPI)