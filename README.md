# A SUMO Trace Filtering Tool for Scalable VANET Simulations

This project is a filtering tool for FCD SUMO traces that aim at making vehicle ad hoc network simulations more scalable.


Below is the help usage of the filtering tool.

**Usage: filterFCD OPTIONS... [FILE]**

Filter fcd output trace from sumo simulation in xml format and save the
 filtered version in ./filtered/ with the prefix \"filtered_\" appended.
 Default option filters vehicles whithin a radial distance of 500 units
 from vehicles of interest.

## Options

  **-v [FILE/STRING]:** Input a csv file with your vehicles of interst; or just a 
                     string with the names of your vehicles separated by space.
                     
  **-k [FILE/STRING]:** Input a csv file with your vehicles to be tracked; or just a 
                     string with the names of your vehicles separated by space.
                     tracked vehicles will be in the final trace even if they are
                     outside the area of interest.
                     
  **-h:**                Displays this help page.
  
  **-c:**               Filter vehicles inside a square arround the vehicles of
                     interest (faster filtering).
                     
  **-r:**               Filter a radial distance from the vehicles of interest.
  **-d [distance]:**     Define the filtering distance used by the cubic and radial
                     filtering. Defaut value is 500 units.
                     
  **j [# max_jumps]:**  Define the maximum number of jumps a infection of interest
                     can have. Default value is 1.
                     
  **-b:**               Delimit the optimal filtering box area arround the vehicles
                     of interest. Vehicle traces outside the box are discarted.
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
                     
  **-z:**               Shift timesteps so that the first timestep is at the moment 
                     0 of the simulation.
                     
