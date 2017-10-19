#!/usr/bin/awk -f

BEGIN {
MKVMerge      = "/usr/bin/mkvmerge" # for linux
FS="[\t\n: ]"
IGNORECASE    = 1
MKVVideo      = ARGV[1]
AudioKeep     = ARGV[2]
SubsKeep      = ARGV[3]
ChaptersKeep  = ARGV[4]
NewVideo      = substr(MKVVideo, 1, length(MKVVideo)-4)".new.mkv"
OrigVideo     = substr(MKVVideo, 1, length(MKVVideo)-4)".OLD.mkv"
shouldProcess = 0
#incase your data is stored on a CIFS Share/Mount set this to 1
CIFSMount     = 1
#get the filename without the extension an .\
VideoName     = substr(MKVVideo, 1, length(MKVVideo)-4)
VideoName     = substr(VideoName, 3, length(VideoName)-2)

#set eng as defaults
if(!AudioKeep){AudioKeep = ":eng:und:dut:jpn"}
if(!SubsKeep){SubsKeep = ":eng:und:dut"}
if(!ChaptersKeep){ChaptersKeep = "chapters"}

do {
    Result=("\""MKVMerge"\" --ui-language en_US --identify-verbose \""MKVVideo"\"" | getline Line)

    if (Result>0) {
        FieldCount=split(Line, Fields)
        if (Fields[1]=="Track") {
            NoTr++
            Track[NoTr, "id"]=Fields[3]
            Track[NoTr, "typ"]=Fields[5]
            Track[NoTr, "xtra"]=Fields[6]
            for (i=6; i<=FieldCount; i++) {
                if (Fields[i]=="language") Track[NoTr, "lang"]=Fields[++i]
            }
        }
    }
}    while (Result>0)
if (NoTr==0) {
    print "Error! No tracks found in \""MKVVideo"\"."
    exit
} else {
    print "\""MKVVideo"\":", NoTr, "tracks found."

    for (q=1; q<=NoTr; q++) {
        print Track[q, "typ"] ": " Track[q, "xtra"]
    }
}
for (i=1; i<=NoTr; i++) {
    if (Track[i, "typ"]=="audio") {
        if (AudioKeep~Track[i, "lang"]) {
            print "Keep", Track[i, "typ"], "Track", Track[i, "id"],  Track[i, "lang"]
            if (AudioCommand=="") {AudioCommand=Track[i, "id"]
            } else AudioCommand=AudioCommand","Track[i, "id"]
        } else {
            print "\tRemove", Track[i, "typ"], "Track", Track[i, "id"],  Track[i, "lang"]
            shouldProcess++
        }
    } else {
        if (Track[i, "typ"]=="subtitles") {
            if (SubsKeep~Track[i, "lang"]) {
                print "Keep", Track[i, "typ"], "Track", Track[i, "id"],  Track[i, "lang"]
                if (SubsCommand=="") {SubsCommand=Track[i, "id"]
                } else SubsCommand=SubsCommand","Track[i, "id"]
            } else {
                print "\tRemove", Track[i, "typ"], "Track", Track[i, "id"],  Track[i, "lang"]
                shouldProcess++
            }
        }
    }
}
if (AudioCommand=="") {CommandLine="-A"
} else {CommandLine="-a "AudioCommand}
if (SubsCommand=="") {CommandLine=CommandLine" -S"
} else {CommandLine=CommandLine" -s "SubsCommand}
if (!ChaptersKeep) CommandLine=CommandLine" --no-chapters"
if(shouldProcess){

    #rename orig vid to old
    print "Moving to backup file: mv \"" MKVVideo "\" \"" OrigVideo "\""
    system("mv \"" MKVVideo "\" \"" OrigVideo "\"")

    #process using mkvmerge
    #--default-track '0:0' makes sure no sub track gets defaulted
    #--title "VideoName set the 'Movie Name' to the name of the file without the extension
    print "CLI: \"" MKVMerge "\" -o \"" MKVVideo "\" " "--default-track '0:0' --title \""VideoName"\" "  CommandLine " \"" OrigVideo "\""
    print "Begin Remux"
    Result=system("\"" MKVMerge "\" -o \"" MKVVideo "\" " "--default-track '0:0' --title \""VideoName"\" "  CommandLine " \"" OrigVideo "\"")
    print "Result: \"" Result "\""
    if(Result == 0){
		if (CIFSMount == 0){
			#if successful, change file permissions of new file unless we use a CIFS share.
			print "Set file permissions on new file: chmod 775 \"" MKVVideo "\""
			system("chmod 775 \"" MKVVideo "\"") 
		}
		#remove old orig video
		print "Delete original file: rm \"" OrigVideo "\""
		system("rm \"" OrigVideo "\"")		
    }


}
else{
    print "Nothing to change, exiting."
}

if (Result>1){ print "Error "Result" muxing \""MKVVideo"\"!"}
}
