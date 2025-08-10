# OpenBuilds Fusion360 Postprocessor

Creates .gcode files optimized for GRBL/grblHAL based Openbuilds-style machines.
Supports router, laser and plasma operations.

V1.0.44
1. Fix movement ordering as suggested by zdima, Fusion360 has changed the order in which it outputs Z retracts causing some movements to
   be G1 when they should be G0.
1. Always output the M code when spindle speed changes.
1. Use onMovement event to track movement type.
1. Tag rapid movements with a comment
1. Split file on line count on a rapid move if possible.
1. Streamline laser/plasma logic for detecting rapid cut avoidance moves.
1. Recenter small arcs always, ignoring the percentage difference in start/end radii.
1. Reset haveRapid after invokeRapid calls to avoid false positives.

V1.0.43
1. Plasma: if tool setting for pierceTime is set AND spindleonoffdelay is 0 then tool.pierceTime will be used.
1. Plasma: if tool setting for PierceHeight is set and pierceHeightoverride is false then tool value will be used.
1. Plasma: if tool setting for cutHeight is set and topHeight is 0 then tool.cutHeight will be used.
   DO read the plasma [instructions](https://github.com/OpenBuilds/OpenBuilds-Fusion360-Postprocessor/blob/master/README-plasma.md) !
1. Fix failure to convert some properties to float values by using parseFloat, seems to be needed due to recent upgrades to Fusion360.

V1.0.42
1. postprocessor.alert() method has disappeared - replaced with warning(msg) and writeComment(msg).
1. moved more stuff into OB. and SPL. to keep it private.

V1.0.41
1. fixes namespace collision with 'power' variable that is now a readonly property of the postprocessor, affects plasma cutting.

V1.0.40
1. force G0 position after plasma probe
1. fix plasma linearization of small arcs to avoid GRBL bug in arc after probe
1. fix pierceClearance and pierceHeight
1. fix plasma kerfWidth to toolRadius calculation

V1.0.39
1. fix missing drill cycles

V1.0.38 and V0.0.2_beta
1. Main post : Simple probing, each axis on its own, and XY corner, for BB4x with 3D probe.
1. Main post : machine simulation enabled.
1. X32 4th axis beta post: machine simulation enabled.

V1.0.37
1. Tape splitting - allows setting a line count after which the gcode is split into a new file, see option 
   _Split on line count (0 for none)_
   in the Toolchange section of the post options.
   (It will also split on toolchanges if both options are selected)

V1.0.36
1. code to recenter arcs with bad radii - this enables use of vertical arcs in lead-in/lead-out moves (you must also enable verticla arcs in the post).

V1.0.35
1. plasma pierce height override,  spindle speed change always with an M3, version number display   

V1.0.34
1. move coolant code to the spindle control line to help with restarts in OpenBuildsCONTROL

V1.0.32
1. fix long comments that were getting extra brackets

V1.0.31
1. improved laser and plasma paths, esp when 'stay down' is selected
1. laser pierce delay option when through cutting is selected
1. Select 'LASER: use Z motions at start and end' to have full Z movement with laser and plasma cuts

V1.0.25 supports plasma torch touchoff probing.
* Read the [instructions](https://github.com/OpenBuilds/OpenBuilds-Fusion360-Postprocessor/blob/master/README-plasma.md)

V1.0.21 now supports plasma cutting

V1.0.20 supports the Personal license restrictions and ultra long comments

V1.0.18 now includes laser operations. 
1. Laser mode supports lasers with and without Z motions.
1. It is left to the operator to correctly set GRBL parameter $32 as needed on a machine that combines a router and laser head.
1. The laser is regarded as an extra tool so when posting multiple operations the
   router code and laser code will be in seperate output .gcode files 
   (exactly as for multiple tool outputs, each tool in its own file).
1. Laser power is scaled between 0 and 1000 (GRBL spindle RPM defaults).  
   You can edit this post to cater for non-default settings. Refer to the 'calcPower' function.

### Credits ###

1. @swarfer David the Swarfer (lead maintainer).
1. @sharmstr - multifile output.
1. @Strooom - Initial work.
1. @AutoDesk - for the example posts and excellent Fusion360 software.
