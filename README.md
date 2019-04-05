# A SUMO Trace Filtering Tool for Scalable VANET Simulations

This project is a filtering tool for FCD SUMO traces that aim at making vehicle ad hoc network simulations more scalable.


Below is the help usage of the filtering tool.

**Usage: filterFCD OPTIONS... [FILE]**

The application filters the FCD output trace from SUMO simulation and save the
 filtered version in ./filtered/ with the prefix "filtered_" appended. The default filtering configuration uses a radial distance of 500 meters around the vehicles of interest and uses neither tracking nor infection of interest. When no vehicles of interest are provided, only the area and time-based filtering are performed if the appropriate arguments are provided.

## Options

  **-v [FILE/STRING]:** Input a csv file with your vehicles of interest; or just a 
                     string with the names of your vehicles separated by space.
                     
  **-k [FILE/STRING]:** Input a csv file with your vehicles to be tracked; or just a 
                     string with the names of your vehicles separated by space.
                     tracked vehicles will be in the final trace even if they are
                     outside the area of interest.
                     
  **-h:**                Displays this help page.
  
  **-c:**               Filter vehicles inside a square around the vehicles of
                     interest (faster filtering).
                     
  **-r:**               Filter a radial distance from the vehicles of interest.
  
  **-d [distance]:**     Define the filtering distance used by the cubic and radial
                     filtering. Default value is 500 units.
                     
  **j [# max_jumps]:**  Define the maximum number of jumps a infection of interest
                     can have. Default value is 1.
                     
  **-b:**               Delimit the optimal filtering box area around the vehicles
                     of interest. Vehicle traces outside the box are discarded.
                     \"distance\" value is used as a buffer space around the box.
                     
  **-b \"x1 y1 x2 y2\":** Filter traces inside the box delimited by \"x1 y1 x2 y2\"
                     defining the lower left and the upper right corner of the
                     area to extract respectively. OPTIONS \"-c\" and \"-r\" are
                     ignored.
                     
  **-t:**               Filter only the timesteps from the trace when a vehicle of
                     interest is present in the simulation.
                     
  **-t \"BEGIN END\":**   Filters only the timesteps from the trace between the
                     timesteps BEGIN and END.
                     
  **-i:**                Vehicles that go inside the filtering area of the trace 
                     are tracked throughout the whole trace, if -1 is given
                     as argument, traces outside of the delimiting box are 
                     ignored.
                     
  **-s:**                Vehicles that go in contact with vehicles of interest become 
                     vehicles of interest themselves (overwrites -i option).
                     
  **-a:**                Vehicles that go in contact with vehicles of interest get 
                     tracked backwards in time and infect others backwards in 
                     time.
                     
  **-o [filename]:**     Renames the output file that is sent to ./filtered/ as "filename".
                     
  **-z:**               Shift timesteps so that the first timestep is at the moment 
                     0 of the simulation.
                     
