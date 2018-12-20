#!/bin/bash
# Has "gawk", "cut", "sed", "cat" and tac as a dependencies

# Initialize default variables
distance=500
filterMode=2

optimal_timesteps=0
optimal_Box=0
boxFilter=0
box_bound=0
Delta_time=0

tracking_F=0
Interest_Infect=0
Time_tracking=0
max_jumps=1

output_file="./filtered/filtered_${!#}"

declare -a tracked_v


# Get the program options
while getopts "crv:k:hd:j:btisazo:" OPTION; do
    case $OPTION in
        h)
echo "Usage: ./filterFCD.sh OPTIONS... [FILE]
Filter fcd output trace from sumo simulation in xml format and save the
 filtered version in ./filtered/ with the prefix \"filtered_\" appended.
 Default option filters vehicles within a radial distance of 500 units
 from vehicles of interest.

OPTIONS:

  -v [FILE/STRING]  Input a csv file with your vehicles of interest; or just a 
                     string with the names of your vehicles separated by space.
  -k [FILE/STRING]  Input a csv file with your vehicles to be tracked; or just a 
                     string with the names of your vehicles separated by space.
                     Tracked vehicles will be in the final trace even if they are
                     outside the area of interest.
  -h                Displays this help page.
  -c                Filter vehicles inside a square around the vehicles of
                     interest (faster filtering).
  -r                Filter a radial distance from the vehicles of interest.
  -d [distance]     Define the filtering distance used by the cubic and radial
                     filtering. Default value is 500 units.
  -j [# max_jumps]  Define the maximum number of jumps a infection of interest
                     can have. Default value is 1.
  -b                Delimit the optimal filtering box area around the vehicles
                     of interest. Vehicle traces that don't go through the box 
                     are discarded. \"distance\" value is used as a buffer space
                     around the box.
  -b \"x1 y1 x2 y2\"  Filter traces inside the box delimited by \"x1 y1 x2 y2\"
                     defining the lower left and the upper right corner of the
                     area to extract respectively.
  -t                Filter only the timesteps from the trace when a vehicle of
                     interest is present in the simulation.
  -t \"BEGIN END\"    Filters only the timesteps from the trace between the
                     timesteps BEGIN and END.
  -i                Vehicles that go inside the filtering area of the trace 
                     are tracked throughout the whole trace. If -1 is given
                     as an argument, traces outside of the delimiting box 
                     from option \"-b\" are ignored and vehicles are not set
                     for tracking.
  -s                Vehicles that go in contact with vehicles of interest become 
                     vehicles of interest themselves.
  -a                Vehicles that go in contact with vehicles of interest get 
                     tracked backwards in time and infect others backwards in 
                     time.
  -o [filename]     Renames the output file that is sent to ./filtered/ as 
                     \"filename\".
  -z                Shift timesteps so that the first timestep is at the moment 
                     0 of the simulation."

        ;;

        o)
        output_file="./filtered/$OPTARG"
        ;;

        d)
        distance=$OPTARG

        if [[ ! $distance =~ ^[0-9]+([\.][0-9]+)?$ ]] 
            then
            echo "Distance (-d) option requires a numerical argument." >&2
            exit 1
        fi
        ;;

        j)
        max_jumps=$OPTARG

        if [[ ! $max_jumps =~ ^[0-9]+$ ]] 
            then
            echo "# max_jumps (-j) option requires a natural number as argument." >&2
            exit 1
        fi
        ;;

        v)
        if [ -f "$OPTARG" ]
        then # Generate an array with the name of all vehicles
            vehicles=($(awk -F',| |\n' 'BEGIN{}{ split($0,a,",| |\n"); for (i in a) print $i; }' $OPTARG))
        else
            vehicles="$OPTARG"
        fi
        ;;

        k)
        if [ -f "$OPTARG" ]
        then # Generate an array with the name of all tracked vehicles
            tracked_v=($(awk -F',| |\n' 'BEGIN{}{ split($0,a,",| |\n"); for (i in a) print $i; }' $OPTARG))
        else
            tracked_v="$OPTARG"
        fi
        ;;

        c)
        filterMode=1
        ;;

        r)
        filterMode=2
        ;;

        b)
        boxFilter=1

        if [[ ${@:$OPTIND:1} =~ ^[0-9]+([\.][0-9]+)?\ [0-9]+([\.][0-9]+)?\ [0-9]+([\.][0-9]+)?\ [0-9]+([\.][0-9]+)?$ ]]
        then
            Box=(${@:$OPTIND:1})
            OPTIND=$((OPTIND+1))
        else
            optimal_Box=1
        fi
        ;;

        i)
        if [[ ${@:$OPTIND:1} =~ ^-1$ ]]
        then
            box_bound=1
            OPTIND=$((OPTIND+1))
        else
            tracking_F=1
        fi
        ;;

        s)
        Interest_Infect=1
        ;;

        a) # vehicles get tracked backwards in time
        Time_tracking=1
        ;;

        t) # Get arguments and set time pre-filtering. If there are no arguments, optimal time filtering is used based on vehicles of interest.

        if [[ ${@:$OPTIND:1} =~ ^[0-9]+([\.][0-9]+)?\ [0-9]+([\.][0-9]+)?$ ]]
        then
            read BEGIN END <<< ${@:$OPTIND:1}
            OPTIND=$((OPTIND+1))
        else
            optimal_timesteps=1
        fi
        ;;

        z)
        Delta_time=1
        ;;

        \?)
        echo "Invalid option given." >&2
        echo "Type \"filterFCD -h\" for help." >&2
        exit 1
        ;;

        :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done
shift $((OPTIND-1))

if [ "$#" -ne 1 ]
    then
    echo "Usage: $0 FILE" >&2
    echo "Type \"filterFCD -h\" for help." >&2
    exit 1
fi

if [ $max_jumps -eq 0 ]
    then
    Interest_Infect=0
    Time_tracking=0
fi

mkdir -p ./filtered

if [[ ! -n "${vehicles[*]}" ]] #  If no vehicles of interest are specified then just filter in time and space
then
    if [[ ! -z $BEGIN ]]
        then awk -v start=$BEGIN -v end=$END '
        BEGIN{
            # define field separator as "
            FS="\"";

            output_line=1
        }

        ( $1=="    <timestep time=" && ($2<start || $2>end) ) {output_line=0; next}
        ( $1=="    <timestep time=" ) {output_line=1}

        output_line;
        END{if (output_line==0) {print "</fcd-export>"}}

    ' $1 ; else cat $1; fi  | if [[ ! -z Box ]]
        then awk -v tracking_F=$tracking_F -v tracked_v="${tracked_v[*]}" -v box_bound=$box_bound -v B_x1=${Box[0]} -v B_y1=${Box[1]} -v B_x2=${Box[2]} -v B_y2=${Box[3]} '
                BEGIN{
                    FS="\""   # define field separator as "
                    counter=0   # index variable for saving lines containing vehicles
                    split(tracked_v, myTracked_v," ") # Initialize myTracked_v as an array
                    split("", temp_v) # Initialize temp_v as an array
                }
                    ( $1~/vehicle/ ){
                        if ( $4<B_x1 || $4>B_x2 || $6<B_y1 || $6>B_y2){
                            for (t in myTracked_v){
                                if ($2==myTracked_v[t]){lines[counter++]=$0; next}
                            }
                            if (tracking_F && $2 in temp_v && box_bound==0){
                                myTracked_v["_"$2]=$2; # If vehicle just got outside of square, it starts being tracked in case it returns
                                lines[counter++]=$0;
                            }
                            next # If outside the box and not tracked, ignore it 
                        }   
                        lines[counter++]=$0
                        next
                    }

                    ($1=="    <timestep time=" ){ lines[counter++]=$0 ; next}

                    # End of a timestep. The lines of the timestep are now processed
                    ( $1=="    </timestep>"){
                        # Print the timestep
                        print lines[0];
                        delete lines[0];
                        delete temp_v; # Clear the vehicles saved from last printed timestep

                        for (n in lines) {
                            $0=lines[n];
                            if (tracking_F){temp_v[$2]}
                            print $0
                        }

                        # Delete tracked vehicle from array if it reached its destination.
                        if (tracking_F && box_bound==0){
                            for (v in myTracked_v ){
                                if(v=="_"myTracked_v[v] && ! myTracked_v[v] in temp_v){delete myTracked_v[v]}
                            }
                        }
                        
                        print "    </timestep>"

                        counter=0

                        # Delete the array (necessitates gawk) more efficiently than using a deletion loop.
                        delete lines  
                        next
                    }

                    1
                ' > output_file; else cat > output_file; fi
else 
    if [ $Time_tracking -eq 1 ]
        then
        case $filterMode in
            1)  # Read the file backwards
                tracked_v=($tracked_v $(if [[ ! -z $BEGIN ]]; then tac $1 | awk -v start=$BEGIN -v end=$END '
                BEGIN{
                    # define field separator as "
                    FS="\"";
                    counter=0; # index variable for saving lines containing vehicles
                }
                
                ( $1=="    <timestep time=" ) {
                    if ($2<start || $2>end){
                        delete lines
                        counter=0
                        next
                    }

                    for (n in lines) {
                        print lines[n]
                    }

                    print $0

                    delete lines
                    counter=0
                    next

                }

                {lines[counter++]=$0}

                ' ; else tac $1; fi  |
                awk -v vehicles="${vehicles[*]}" -v distance=$distance -v max_jumps=$max_jumps '
                # Need this because awk doesnt have abs() function:
                function abs(value)
                {
                    return (value<0?-value:value);
                }

                function cDistance(X,x,Y,y){
                    return abs((X-x))<abs((Y-y)) ? abs(Y-y) : abs(X-x)
                }

                BEGIN{FS="\""; # define field separator as "

                counter=0; # index variable for saving lines containing vehicles

                split(vehicles,myVehicles," ") # create a list of vehicles of interest

                # Initialize variables as arrays
                split("", my_x)
                split("", my_y)
                }
                {
                # Save vehicle lines and get vehicle of interest locations
                if ( $1~/vehicle/ ){
                    lines[counter++]=$0;

                    for (v in myVehicles){
                        if ($2==myVehicles[v] && v!=max_jumps"_"$2) {
                            my_x[v]=$4;
                            my_y[v]=$6;
                            break
                        }
                    }
                }
                # End of a timestep. The lines of the timestep are now processed
                else if ($1=="    <timestep time=" ){
                    if ( length(my_x)==0 ){delete lines; counter=0; next;}
                    
                    # The existence of my_x shows that the vehicle of interest exists in this timestep
                    # Now that we know that this timestep is relevant we can find if other vehicles are infected

                    for (n in lines) {
                        $0=lines[n]
                        is_interestV=0

                        # my_x have the keys of myVehicles that exist in the timestep
                        for (y in myVehicles){

                            # Vehicle from line is vehicle of interest
                            if ($2==myVehicles[y]){ 
                                is_interestV=y # Get the key to vehicle of interest on line being processed
                                break
                            }
                        }

                        for (v in my_x){

                            x=match(v,/^[0-9]+_/) ? substr(v,1,RLENGTH-1) : max_jumps

                            if (is_interestV){

                                if ( match(is_interestV,/^[0-9]+_/)){

                                    if (substr(is_interestV,1,RLENGTH-1)>x+1 && cDistance($4,my_x[v],$6,my_y[v]) < distance){
                                        delete myVehicles[is_interestV]
                                        is_interestV=x+1"_"$2
                                        myVehicles[is_interestV]=$2      
                                    }
                                    continue
                                }
                                break
                                
                            }


                            else if (cDistance($4,my_x[v],$6,my_y[v]) < distance){
                                if(x<max_jumps){
                                    is_interestV=x+1"_"$2
                                    myVehicles[is_interestV]=$2
                                }

                                else{
                                    # added a string at the begining so an overwrite to a number key already existent doesnt happen
                                    # "1_" indicate that it is the first jump of the infection
                                    myVehicles[1"_"$2]=$2;
                                    break
                                }
                            }
                        }

                    }
                    counter=0;

                    # Delete the array (necessitates gawk) more efficiently than using a deletion loop.
                    delete lines;
                    delete my_x;
                    delete my_y;
                    
                }
                }
                END{
                    for (v in myVehicles){
                        print myVehicles[v]
                    }
                }
                ')
                )

            ;;

            2)
                tracked_v=($tracked_v $(if [[ ! -z $BEGIN ]]; then tac $1 | awk -v start=$BEGIN -v end=$END '
                BEGIN{
                    # define field separator as "
                    FS="\"";
                    counter=0; # index variable for saving lines containing vehicles
                }
                
                ( $1=="    <timestep time=" ) {
                    if ($2<start || $2>end){
                        delete lines
                        counter=0
                        next
                    }

                    for (n in lines) {
                        print lines[n]
                    }
                    
                    print $0

                    delete lines
                    counter=0
                    next

                }

                {lines[counter++]=$0}

                ' ; else tac $1; fi  |
                awk -v vehicles="${vehicles[*]}" -v distance=$distance -v max_jumps=$max_jumps '
                function rDistance(X,x,Y,y){
                    return sqrt( (X-x)**2+(Y-y)**2)
                }

                BEGIN{FS="\""; # define field separator as "

                counter=0; # index variable for saving lines containing vehicles

                split(vehicles,myVehicles," ") # create a list of vehicles of interest

                # Initialize variables as arrays
                split("", my_x)
                split("", my_y)
                }
                {
                # Save vehicle lines and get vehicle of interest locations
                if ( $1~/vehicle/ ){
                    lines[counter++]=$0;

                    for (v in myVehicles){
                        if ($2==myVehicles[v] && v!=max_jumps"_"$2) {
                            my_x[v]=$4;
                            my_y[v]=$6;
                            break
                        }
                    }
                }
                # End of a timestep. The lines of the timestep are now processed
                else if ($1=="    <timestep time=" ){
                    if ( length(my_x)==0 ){delete lines; counter=0; next;}
                    
                    # The existence of my_x shows that the vehicle of interest exists in this timestep
                    # Now that we know that this timestep is relevant we can find if other vehicles are infected

                    for (n in lines) {
                        $0=lines[n]
                        is_interestV=0

                        # my_x have the keys of myVehicles that exist in the timestep
                        for (y in myVehicles){

                            # Vehicle from line is vehicle of interest
                            if ($2==myVehicles[y]){ 
                                is_interestV=y # Get the key to vehicle of interest on line being processed
                                break
                            }
                        }

                        for (v in my_x){

                            x=match(v,/^[0-9]+_/) ? substr(v,1,RLENGTH-1) : max_jumps

                            if (is_interestV){

                                if ( match(is_interestV,/^[0-9]+_/)){

                                    if (substr(is_interestV,1,RLENGTH-1)>x+1 && cDistance($4,my_x[v],$6,my_y[v]) < distance){
                                        delete myVehicles[is_interestV];
                                        is_interestV=x+1"_"$2;
                                        myVehicles[is_interestV]=$2      
                                    }
                                    continue
                                }
                                break
                                
                            }

                            else if (rDistance($4,my_x[v],$6,my_y[v]) < distance){
                                if(x<max_jumps){
                                    is_interestV=x+1"_"$2
                                    myVehicles[is_interestV]=$2
                                }

                                else{
                                    # added a string at the beginning so an overwrite to a number key already existent doesnt happen
                                    # "1_" indicate that it is the first jump of the infection
                                    myVehicles[1"_"$2]=$2;
                                    break
                                }
                            }
                        }

                    }
                    counter=0;

                    # Delete the array (necessitates gawk) more efficiently than using a deletion loop.
                    delete lines;
                    delete my_x;
                    delete my_y;
                    
                }
                }
                END{
                    for (v in myVehicles){
                        print myVehicles[v]
                    }
                }
                ')
                )
            ;;
        esac

    fi

    if [[ boxFilter -eq 1 ]]; then
        if [[ $optimal_Box -eq 1 ]] # If optimal_Box==1 then a first scan is necessary to get the ideal bounding box.
        then 
            # First the file is time filtered if BEGIN and END are specified. Then, they are piped to an awk.
            Box=($(if [[ ! -z $BEGIN ]]; then awk -v start=$BEGIN -v end=$END '
                BEGIN{
                    # define field separator as "
                    FS="\"";

                    output_line=1
                }

                ( $1=="    <timestep time=" && ($2<start || $2>end) ) {output_line=0; next}
                ( $1=="    <timestep time=" ) {output_line=1}

                output_line;
                ' $1; else cat $1; fi  |
                awk -v vehicles="${vehicles[*]}" -v distance=$distance -v min_x=inf -v min_y=inf -v max_x=-inf -v max_y=-inf '
                    BEGIN{FS="\""; # define field separator as "
                    split(vehicles,myVehicles," ") # create a list of vehicles of interest.
                    }
                    $1~/vehicle/{
                        for (v in myVehicles){
                            if ($2==myVehicles[v]) {

                                # check x
                                if (mix_x>$4) {min_x=$4} 
                                else if(max_x<$4) {max_x=$4}

                                # check y
                                if(mix_y>$6) {min_y=$6} 
                                else if(max_y<$6) {max_y=$6}
                            }
                        }
                    }
                    END{
                        print (min_x-distance, min_y-distance, max_x+distance, max_y+distance)
                    }
                ')
            );
        fi

        # If optimal_Box==0 just get the bounding box points and filter.
        if [[ ! -z $BEGIN ]]
            then # First the file is time filtered if BEGIN and END are specified. Then, they are piped to an awk.
            awk -v start=$BEGIN -v end=$END '
            BEGIN{
                # define field separator as "
                FS="\"";

                output_line=1
            }

            ( $1=="    <timestep time=" && ($2<start || $2>end) ) {output_line=0; next}
            ( $1=="    <timestep time=" ) {output_line=1}

            output_line

            END{if (output_line==0) {print "</fcd-export>"}}
            ' $1 ; else cat $1; fi  | 
        awk -v vehicles="${vehicles[*]}" -v tracked_v="${tracked_v[*]}" -v tracking_F=$tracking_F -v optTime=$optimal_timesteps -v box_bound=$box_bound -v B_x1=${Box[0]} -v B_y1=${Box[1]} -v B_x2=${Box[2]} -v B_y2=${Box[3]} '
                    BEGIN{FS="\""   # define field separator as "

                    counter=0   # index variable for saving lines containing vehicles

                    split(vehicles,myVehicles," ")   # create a list of vehicles of interest
                    split(tracked_v,myTracked_v," ") # create a list of vehicles being tracked

                    split("", temp_v) # Initialize temp_v as an array

                    my_car_F=0   # Car flag to indicate the presence of a vehicle of interest

                    }
                    {
                        if ( $1~/vehicle/ ){
                            if ( $4<B_x1 || $4>B_x2 || $6<B_y1 || $6>B_y2){ 
                                for (t in myTracked_v){
                                    if ($2==myTracked_v[t]){lines[counter++]=$0; next}
                                }
                                if (tracking_F && $2 in temp_v && box_bound==0){
                                    myTracked_v["_"$2]=$2; # If vehicle just got outside of square, it starts being tracked in case it returns
                                    lines[counter++]=$0;
                                }
                                next # If outside the box and not tracked, ignore it 
                            }   

                            lines[counter++]=$0

                            if (optTime){
                                for (v in myVehicles){
                                    if (my_car_F==0 && $2==myVehicles[v]) {
                                        my_car_F=1
                                        break
                                    }
                                }
                            }
                        }

                        else if ($1=="    <timestep time=" ){ lines[counter++]=$0 }

                        # End of a timestep. The lines of the timestep are now processed
                        else if ( $1=="    </timestep>"){
                            if (optTime && my_car_F==0 ){delete lines; counter=0; next}
                            
                            # Now that we know that this timestep is relevant we can print all lines from it
                            print lines[0];
                            delete lines[0];
                            delete temp_v; # Clear the vehicles saved from last printed timestep

                            for (n in lines) {
                                $0=lines[n];
                                temp_v[$2]
                                print $0
                            }

                            # Free up memory if tracked vehicle finished its trip
                            if (tracking_F && box_bound==0){
                                for (v in myTracked_v ){
                                    if(v=="_"myTracked_v[v] && ! myTracked_v[v] in temp_v){delete myTracked_v[v]}
                                }
                            }
                            
                            print "    </timestep>"

                            counter=0
                            my_car_F=0

                            # Delete the array (necessitates gawk) more efficiently than using a deletion loop.
                            delete lines  
                        }
                        else print
                    }
                    '

    elif [[ ! -z $BEGIN ]]
        then # First the file is time filtered if BEGIN and END are specified and it was not already filtered by "boxFilter". Then, they are piped to an awk.
        awk -v start=$BEGIN -v end=$END '
        BEGIN{
            # define field separator as "
            FS="\"";

            output_line=1
        }

        ( $1=="    <timestep time=" && ($2<start || $2>end) ) {output_line=0; next}
        ( $1=="    <timestep time=" ) {output_line=1}

        output_line

        END{if (output_line==0) {print "</fcd-export>"}}
        ' $1 ; else cat $1 
    fi  | 

    case $filterMode in
    1) # If vehicles that made contact need to be tracked backwards in time
    # Calls the awk that uses single coordenate distance after time filtering.
    awk -v vehicles="${vehicles[*]}" -v tracked_v="${tracked_v[*]}" -v distance=$distance -v max_jumps=$max_jumps -v optTime=$optimal_timesteps -v tracking_F=$tracking_F -v Interest_Infect=$Interest_Infect '
        # Need this because awk doesnt have abs() function:
        function abs(value)
        {
            return (value<0?-value:value);
        }

        function cDistance(X,x,Y,y){
            return abs((X-x))<abs((Y-y)) ? abs(Y-y) : abs(X-x)
        }

        BEGIN{FS="\""; # define field separator as "

        counter=0; # index variable for saving lines containing vehicles
        tracked_Found=0;
        myVehicle_Found=0;

        split(vehicles,myVehicles," ") # create a list of vehicles of interest
        split(tracked_v,myTracked_v," ") # create a list of vehicles being tracked

        # Initialize variables as arrays
        split("", my_x)
        split("", my_y)
        }
        {
        # Save vehicle lines and get vehicle of interest locations
        if ( $1~/vehicle/ ){
            lines[counter++]=$0;

            for (v in myVehicles){
                if ($2==myVehicles[v]) {
                    my_x[v]=$4;
                    my_y[v]=$6;
                    break
                }
            }
        }

        else if ($1=="    <timestep time=" ){ lines[counter++]=$0;}

        # End of a timestep. The lines of the timestep are now processed
        else if ($1=="    </timestep>"){
            if (optTime==1 && length(my_x)==0){delete lines; counter=0; next;}
            # The existence of my_x shows that the vehicle of interest exists in this timestep

            # Now that we know that this timestep is relevant we can print its line
            print lines[0];
            delete lines[0];

            for (n in lines) {
                next_line=0;
                $0=lines[n];
                temp_v[$2];

                # If vehicle is tracked, print it
                for (t in myTracked_v){
                    if ($2==myTracked_v[t]){
                        print $0;
                        next_line=1;

                        if (Interest_Infect){
                            for (v in my_x){
                                if (cDistance($4,my_x[v],$6,my_y[v]) < distance){
                                    x=match(v,/^[0-9]+_/) ? substr(v,1,RLENGTH-1) : -1

                                    if (x==max_jumps){continue}

                                    else if (x<0){
                                        # If x is negative, it indicates that v is one of the originals vehicles of interest.
                                        # "1_" indicate that it is the first jump of the infection
                                        delete myTracked_v[t]
                                        myVehicles[1"_"$2]=$2;
                                    }
                                    else{
                                        delete myTracked_v[t];
                                        myVehicles[x+1"_"$2]=$2
                                    }
                                    break
                                }
                            }
                        }
                        
                        break
                    }
                }
                if (next_line){continue} # Workaround to use multilevel continues.

                if (Interest_Infect){
                    print_line=0;
                    is_interestV=0;
                    min_jumpsToV=max_jumps;


                    # my_x have the keys of myVehicles that exist in the timestep
                    for (y in my_x){

                        # Vehicle from line is vehicle of interest
                        if ($2==myVehicles[y]){ 

                            is_interestV=y # Get the key to vehicle of interest on line being processed
                            print_line=1
                        }
                    }

                    for (v in my_x){

                        x=match(v,/^[0-9]+_/) ? substr(v,1,RLENGTH-1) : max_jumps+1

                        if (is_interestV){

                            if ( match(is_interestV,/^[0-9]+_/)){

                                if (substr(is_interestV,1,RLENGTH-1)>x+1 && cDistance($4,my_x[v],$6,my_y[v]) < distance){
                                    delete myVehicles[is_interestV]
                                    is_interestV=x+1"_"$2
                                    myVehicles[is_interestV]=$2      
                                }
                                continue
                            }
                            break
                            
                        }

                        else if (cDistance($4,my_x[v],$6,my_y[v]) < distance){

                            if (x==max_jumps){
                                if (tracking_F){myTracked_v["_"$2]=$2} 
                                print_line=1;
                                continue
                            }

                            else if (x>max_jumps){
                                # If x is greater than max_jumps, it indicates that v is one of the originals vehicles of interest.
                                # "1_" indicate that it is the first jump of the infection
                                min_jumpsToV=0
                                print_line=1
                                break
                            }
                            else if(x<min_jumpsToV){
                                min_jumpsToV=x
                                print_line=1
                                continue
                            }
                        }
                    }
                    if (min_jumpsToV<max_jumps){
                        if (tracking_F){myTracked_v["_"$2]=$2} 
                        myVehicles[min_jumpsToV+1"_"$2]=$2
                    }

                    if (print_line){print $0}
                }
                else{
                    for (v in my_x){
                        if ($2==myVehicles[v]){print $0; next_line=1;break}
                    }
                    if (next_line){continue}

                    for (v in my_x){
                        if (cDistance($4,my_x[v],$6,my_y[v]) < distance){
                            # added a string at the beginning so an overwrite to a number key already existent doesnt happen
                            if (tracking_F){myTracked_v["_"$2]=$2} 

                            print $0

                            break 
                        }
                    }
                }
            }

            # Free up memory if vehicle of interest finished its trip
            if (Interest_Infect){
                for (v in myVehicles ){
                    if(v~/^[0-9]+_/ && ! myVehicles[v] in temp_v){delete myVehicles[v]}
                }
            }

            # Free up memory if tracked vehicle finished its trip
            if (tracking_F){
                for (v in myTracked_v ){
                    if(v=="_"myTracked_v[v] && ! myTracked_v[v] in temp_v){delete myTracked_v[v]}
                }
            }

            print "    </timestep>";

            counter=0;

            # Delete the array (necessitates gawk) more efficiently than using a deletion loop.
            delete lines;
            delete my_x;
            delete my_y;
            delete temp_v
        }

        else print


        }' > "output_file"
    ;;



    2) # First the file is time filtered if BEGIN and END are specified. Then, they are piped to an awk
    # Calls the awk that filters by radial distance after time filtering.
    awk -v vehicles="${vehicles[*]}" -v tracked_v="${tracked_v[*]}" -v distance=$distance -v max_jumps=$max_jumps -v optTime=$optimal_timesteps -v tracking_F=$tracking_F -v Interest_Infect=$Interest_Infect '

        function rDistance(X,x,Y,y){
            return sqrt( (X-x)**2+(Y-y)**2)
        }

        BEGIN{FS="\""; # define field separator as "

        counter=0; # index variable for saving lines containing vehicles
        tracked_Found=0;
        myVehicle_Found=0;

        split(vehicles,myVehicles," ") # create a list of vehicles of interest
        split(tracked_v,myTracked_v," ") # create a list of vehicles being tracked

        # Initialize variables as arrays
        split("", my_x)
        split("", my_y)
        }
        {
        # Save vehicle lines and get vehicle of interest locations
        if ( $1~/vehicle/ ){
            lines[counter++]=$0;

            for (v in myVehicles){
                if ($2==myVehicles[v]) {
                    my_x[v]=$4;
                    my_y[v]=$6;
                    break
                }
            }
        }

        else if ($1=="    <timestep time=" ){ lines[counter++]=$0;}

        # End of a timestep. The lines of the timestep are now processed
        else if ($1=="    </timestep>"){
            if (optTime==1 && length(my_x)==0){delete lines; counter=0; next;}
            # The existence of my_x shows that the vehicle of interest exists in this timestep

            # Now that we know that this timestep is relevant we can print its line
            print lines[0];
            delete lines[0];

            for (n in lines) {
                next_line=0;
                $0=lines[n];
                temp_v[$2];

                # If vehicle is tracked, print it
                for (t in myTracked_v){
                    if ($2==myTracked_v[t]){
                        print $0;
                        next_line=1;

                        if (Interest_Infect){
                            min_jumpsToV=0
                            for (v in my_x){
                                x=match(v,/^[0-9]+_/) ? substr(v,1,RLENGTH-1) : -1

                                if (x==max_jumps){continue}

                                if (rDistance($4,my_x[v],$6,my_y[v]) < distance){

                                    if (x<0){
                                        # If x is negative, it indicates that v is one of the originals vehicles of interest.
                                        # "1_" indicate that it is the first jump of the infection
                                        min_jumpsToV=0
                                        break
                                    }
                                    else if(x<min_jumpsToV){
                                        min_jumpsToV=x
                                        myVehicles[x+1"_"$2]=$2
                                    }
                                }
                            }
                            if (min_jumpsToV<max_jumps){
                                delete myTracked_v[t];
                                myVehicles[min_jumpsToV+1"_"$2]=$2
                            }
                        }
                        
                        break
                    }
                }
                if (next_line){continue} # Workaround to use multilevel continues.

                if (Interest_Infect){
                    print_line=0;
                    is_interestV=0;
                    min_jumpsToV=max_jumps;


                    # my_x have the keys of myVehicles that exist in the timestep
                    for (y in my_x){

                        # Vehicle from line is vehicle of interest
                        if ($2==myVehicles[y]){ 

                            is_interestV=y # Get the key to vehicle of interest on line being processed
                            print_line=1
                        }
                    }

                    for (v in my_x){

                        x=match(v,/^[0-9]+_/) ? substr(v,1,RLENGTH-1) : max_jumps+1

                        if (is_interestV){

                            if ( match(is_interestV,/^[0-9]+_/)){

                                if (substr(is_interestV,1,RLENGTH-1)>x+1 && rDistance($4,my_x[v],$6,my_y[v]) < distance){
                                    delete myVehicles[is_interestV]
                                    is_interestV=x+1"_"$2
                                    myVehicles[is_interestV]=$2      
                                }
                                continue
                            }
                            break
                            
                        }

                        else if (rDistance($4,my_x[v],$6,my_y[v]) < distance){

                            if (x==max_jumps){
                                if (tracking_F){myTracked_v["_"$2]=$2} 
                                print_line=1;
                                continue
                            }

                            else if (x>max_jumps){
                                # If x is greater than max_jumps, it indicates that v is one of the originals vehicles of interest.
                                # "1_" indicate that it is the first jump of the infection
                                min_jumpsToV=0
                                print_line=1
                                break
                            }
                            else if(x<min_jumpsToV){
                                min_jumpsToV=x
                                print_line=1
                                continue
                            }
                        }
                    }
                    if (min_jumpsToV<max_jumps){
                        if (tracking_F){myTracked_v["_"$2]=$2} 
                        myVehicles[min_jumpsToV+1"_"$2]=$2
                    }

                    if (print_line){print $0}
                }
                else{
                    for (v in my_x){
                        if ($2==myVehicles[v]){print $0; next_line=1;break}
                    }
                    if (next_line){continue}

                    for (v in my_x){
                        if (rDistance($4,my_x[v],$6,my_y[v]) < distance){
                            # added a string at the beginning so an overwrite to a number key already existent doesnt happen
                            if (tracking_F){myTracked_v["_"$2]=$2} 

                            print $0

                            break 
                        }
                    }
                }
            }

            # Free up memory if vehicle of interest finished its trip
            if (Interest_Infect){
                for (v in myVehicles ){
                    if(v~/^[0-9]+_/ && ! myVehicles[v] in temp_v){delete myVehicles[v]}
                }
            }

            # Free up memory if tracked vehicle finished its trip
            if (tracking_F){
                for (v in myTracked_v ){
                    if(v=="_"myTracked_v[v] && ! myTracked_v[v] in temp_v){delete myTracked_v[v]}
                }
            }

            print "    </timestep>";

            counter=0;

            # Delete the array (necessitates gawk) more efficiently than using a deletion loop.
            delete lines;
            delete my_x;
            delete my_y;
            delete temp_v
        }

        else print


        }' > "output_file"
    ;;
    esac
fi

if [[ Delta_time -eq 1 ]]
    then
    awk '
    BEGIN{
        FS="\""   # define field separator as "
        split("", temp_v) # Initialize temp_v as an array
        first_timestep=0
    }
        ($1=="    <timestep time="){ 
            if (! first_timestep){first_timestep=$2}
            $2="\""$2-first_timestep"\""
        }
        1
    ' output_file > ./filtered/D_filtered_$1

mv -f ./filtered/D_filtered_$1 output_file
fi
