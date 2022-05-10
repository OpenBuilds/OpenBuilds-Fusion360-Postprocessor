/*
Custom Post-Processor for GRBL based Openbuilds-style CNC machines, router and laser-cutting
Made possible by
Swarfer  https://github.com/swarfer/GRBL-Post-Processor
Sharmstr https://github.com/sharmstr/GRBL-Post-Processor
Strooom  https://github.com/Strooom/GRBL-Post-Processor
This post-Processor should work on GRBL-based machines

Changelog
22/Aug/2016 - V01     : Initial version (Stroom)
23/Aug/2016 - V02     : Added Machining Time to Operations overview at file header (Stroom)
24/Aug/2016 - V03     : Added extra user properties - further cleanup of unused variables (Stroom)
07/Sep/2016 - V04     : Added support for INCHES. Added a safe retract at beginning of first section (Stroom)
11/Oct/2016 - V05     : Update (Stroom)
30/Jan/2017 - V06     : Modified capabilities to also allow waterjet, laser-cutting (Stroom)
28 Jan 2018 - V07     : Fix arc errors and add gotoMCSatend option (Swarfer)
16 Feb 2019 - V08     : Ensure X, Y, Z  output when linear differences are very small (Swarfer)
27 Feb 2019 - V09     : Correct way to force word output for XYZIJK, see 'force:true' in CreateVariable (Swarfer)
27 Feb 2018 - V10     : Added user properties for router type. Added rounding of dial settings to 1 decimal (Sharmstr)
16 Mar 2019 - V11     : Added rounding of tool length to 2 decimals.  Added check for machine config in setup (Sharmstr)
                      : Changed RPM warning so it includes operation. Added multiple .nc file generation for tool changes (Sharmstr)
                      : Added check for duplicate tool numbers with different geometry (Sharmstr)
17 Apr 2019 - V12     : Added check for minimum  feed rate.  Added file names to header when multiple are generated  (Sharmstr)
                      : Added a descriptive title to gotoMCSatend to better explain what it does.
                      : Moved machine vendor, model and control to user properties  (Sharmstr)
15 Aug 2019 - V13     : Grouped properties for clarity  (Sharmstr)
05 Jun 2020 - V14     : description and comment changes (Swarfer)
09 Jun 2020 - V15     : remove limitation to MM units - will produce inch output but user must note that machinehomeX/Y/Z values are always MILLIMETERS (Swarfer)
10 Jun 2020 - V1.0.16 : OpenBuilds-Fusion360-Postprocessor, Semantic Versioning, Automatically add router dial if Router type is set (OpenBuilds)
11 Jun 2020 - V1.0.17 : Improved the header comments, code formatting, removed all tab chars, fixed multifile name extensions
21 Jul 2020 - V1.0.18 : Combined with Laser post - will output laser file as if an extra tool.
08 Aug 2020 - V1.0.19 : Fix for spindleondelay missing on subfiles
02 Oct 2020 - V1.0.20 : Fix for long comments and new restrictions
05 Nov 2020 - V1.0.21 : poweron/off for plasma, coolant can be turned on for laser/plasma too
04 Dec 2020 - V1.0.22 : Add Router11 and dial settings
16 Jan 2021 - V1.0.23 : Remove end of file marker '%' from end of output, arcs smaller than toolRadius will be linearized
25 Jan 2021 - V1.0.24 : Improve coolant codes
26 Jan 2021 - V1.0.25 : Plasma pierce height, and probe
29 Aug 2021 - V1.0.26 : Regroup properties for display, Z height check options
03 Sep 2021 - V1.0.27 : Fix arc ramps not changing Z when they should have
12 Nov 2021 - V1.0.28 : Added property group names, fixed default router selection, now uses permittedCommentChars  (sharmstr)
24 Nov 2021 - V1.0.28 : Improved coolant selection, tweaked property groups, tweaked G53 generation, links for help in comments.
21 Feb 2022 - V1.0.29 : Fix sideeffects of drill operation having rapids even when in noRapid mode by always resetting haveRapid in onSection
10 May 2022 - V1.0.30 : Change naming convention for first file in multifile output
*/
obversion = 'V1.0.30';
description = "OpenBuilds CNC : GRBL/BlackBox";  // cannot have brackets in comments
longDescription = description + " : Post" + obversion; // adds description to post library diaglog box
vendor = "OpenBuilds";
vendorUrl = "https://openbuilds.com";
model = "GRBL";
legal = "";
certificationLevel = 2;

extension = "gcode";                            // file extension of the gcode file
setCodePage("ascii");                           // character set of the gcode file
//setEOL(CRLF);                                 // end-of-line type : use CRLF for windows

var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,=_-*/\\:";
capabilities = CAPABILITY_MILLING | CAPABILITY_JET;      // intended for a CNC, so Milling, and waterjet/plasma/laser
tolerance = spatial(0.01, MM);
minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.125, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.1); // was 0.01
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = (1 << PLANE_XY);// | (1 << PLANE_ZX) | (1 << PLANE_YZ); // only XY, ZX, and YZ planes
// the above circular plane limitation appears to be a solution to the faulty arcs problem (but is not entirely)
// an alternative is to set EITHER minimumChordLength OR minimumCircularRadius to a much larger value, like 0.5mm

// user-defined properties : defaults are set, but they can be changed from a dialog box in Fusion when doing a post.
properties =
{
   spindleOnOffDelay: 1.8,        // time (in seconds) the spindle needs to get up to speed or stop, or laser/plasma pierce delay
   spindleTwoDirections : false,  // true : spindle can rotate clockwise and counterclockwise, will send M3 and M4. false : spindle can only go clockwise, will only send M3
   hasCoolant : false,            // true : machine uses the coolant output, M8 M9 will be sent. false : coolant output not connected, so no M8 M9 will be sent
   routerType : "other",
   generateMultiple: true,        // specifies if a file should be generated for each tool change
   machineHomeZ : -10,            // absolute machine coordinates where the machine will move to at the end of the job - first retracting Z, then moving home X Y
   machineHomeX : -10,            // always in millimeters
   machineHomeY : -10,
   gotoMCSatend : false,          // true will do G53 G0 x{machinehomeX} y{machinehomeY}, false will do G0 x{machinehomeX} y{machinehomeY} at end of program
   PowerVaporise : 100,    // cutting power in percent
   PowerThrough  : 50,
   PowerEtch     : 2,
   UseZ : false,           // if true then Z will be moved to 0 at beginning and back to 'retract height' at end
   //plasma stuff
   plasma_usetouchoff : false, // use probe for touchoff if true
   plasma_touchoffOffset : 5.0, // offset from trigger point to real Z0, used in G10 line

   linearizeSmallArcs: true,     // arcs with radius < toolRadius have radius errors, linearize instead?
   machineVendor : "OpenBuilds",
   modelMachine : "Generic",
   machineControl : "Grbl 1.1 / BlackBox",

   checkZ : false,    // true for a PS tool height checkmove at start of every file
   checkFeed : 200    // always MM/min
   //postProcessorDocs : 'https://docs.openbuilds.com/doku.php', // for future use.  link to post processor help docs.  be sure to uncomment comment as well
};

// user-defined property definitions - note, do not skip any group numbers
groupDefinitions = {
    //postInfo: {title: "OpenBuilds Post Documentation: https://docs.openbuilds.com/doku.php", description: "", order: 0},
    spindle: {title: "Spindle", description: "Spindle options", order: 1},
    safety: {title: "Safety", description: "Safety options", order: 2},
    toolChange: {title: "Tool Changes", description: "Tool change options", order: 3},
    startEndPos: {title: "Job Start Z and Job End X,Y,Z Coordinates", description: "Set the spindle start and end position", order: 4},
    arcs: {title: "Arcs", description: "Arc options", order: 5},
    laserPlasma: {title: "Laser / Plasma", description: "Laser / Plasma options", order: 6},
    machine: {title: "Machine", description: "Machine options", order: 7}
};
propertyDefinitions = {
/*
    postProcessorDocs: {
        group: "postInfo",
        title: "Copy and paste linke to docs",
        description: "Link to docs",
        type: "string",
    },
*/
   routerType:  {
      group: "spindle",
      title: "SPINDLE Router type",
      description: "Select the type of spindle you have.",
      type: "enum",
      values:[
        {title:"Other", id:"other"},
        {title:"Router11", id:"Router11"},
        {title:"Makita RT0701", id:"Makita"},
        {title:"Dewalt 611", id:"Dewalt"}
      ]
   },
   spindleTwoDirections:  {
      group: "spindle",
      title: "SPINDLE can rotate clockwise and counterclockwise?",
      description:  "Yes : spindle can rotate clockwise and counterclockwise, will send M3 and M4. No : spindle can only go clockwise, will only send M3",
      type: "boolean",
    },
    spindleOnOffDelay:  {
      group: "spindle",
      title: "SPINDLE on/off delay",
      description: "Time (in seconds) the spindle needs to get up to speed or stop, also used for plasma pierce delay",
      type: "number",
    },
    hasCoolant:  {
      group: "spindle",
      title: "SPINDLE Has coolant?",
      description: "Yes: machine uses the coolant output, M8 M9 will be sent. No : coolant output not connected, so no M8 M9 will be sent",
      type: "boolean",
    },
    checkFeed:  {
      group: "safety",
      title: "SAFETY: Check tool feedrate",
      description: "Feedrate to be used for the tool length check, always millimeters.",
      type: "spatial",
    },
    checkZ:  {
      group: "safety",
      title: "SAFETY: Check tool Z length?",
      description: "Insert a safe move and program pause M0 to check for tool length, tool will lower to clearanceHeight set in the Heights tab.",
      type: "boolean",
    },

   generateMultiple: {
      group: "toolChange",
      title:"TOOL: Generate muliple files for tool changes?",
      description: "Generate multiple files. One for each tool change.",
      type:"boolean",
    },

   gotoMCSatend: {
      group: "startEndPos",
      title:"EndPos: Use Machine Coordinates (G53) at end of job?",
      description: "Yes will do G53 G0 x{machinehomeX} y(machinehomeY) (Machine Coordinates), No will do G0 x(machinehomeX) y(machinehomeY) (Work Coordinates) at end of program",
      type:"boolean",
   },
   machineHomeX: {
      group: "startEndPos",
      title:"EndPos: End of job X position (MM).",
      description: "(G53 or G54) X position to move to in Millimeters",
      type:"spatial",
   },
   machineHomeY: {
      group: "startEndPos",
      title:"EndPos: End of job Y position (MM).",
      description: "(G53 or G54) Y position to move to in Millimeters.",
      type:"spatial",
   },
   machineHomeZ: {
      group: "startEndPos",
      title:"startEndPos: START and End of job Z position (MCS Only) (MM)",
      description: "G53 Z position to move to in Millimeters, normally negative.  Moves to this distance below Z home.",
      type:"spatial",
   },

   linearizeSmallArcs: {
      group: "arcs",
      title:"ARCS: Linearize Small Arcs",
      description: "Arcs with radius < toolRadius can have mismatched radii, set this to Yes to linearize them. This solves G2/G3 radius mismatch errors.",
      type:"boolean",
   },

   PowerVaporise: {title:"LASER: Power for Vaporizing", description:"Scary power VAPORIZE power setting, in percent.", group:"laserPlasma", type:"integer"},
   PowerThrough:  {title:"LASER: Power for Through Cutting", description:"Normal Through cutting power, in percent.", group:"laserPlasma", type:"integer"},
   PowerEtch:     {title:"LASER: Power for Etching", description:"Just enough power to Etch the surface, in percent.", group:"laserPlasma", type:"integer"},
   UseZ:          {title:"LASER: Use Z motions at start and end.", description:"Use True if you have a laser on a router with Z motion, or a PLASMA cutter.", group:"laserPlasma", type:"boolean"},
   plasma_usetouchoff:  {title:"PLASMA: Use Z touchoff probe routine", description:"Set to true if have a touchoff probe for Plasma.", group:"laserPlasma", type:"boolean"},
   plasma_touchoffOffset:{title:"PLASMA: Plasma touch probe offset", description:"Offset in Z at which the probe triggers, always Millimeters, always positive.", group:"laserPlasma", type:"spatial"},

   machineVendor: {
      group: "machine",
      title:"Machine Vendor",
      description: "Machine vendor defined here will be displayed in header if machine config not set.",
      type:"string",
   },
   modelMachine: {
      group: "machine",
      title:"Machine Model",
      description: "Machine model defined here will be displayed in header if machine config not set.",
      type:"string",
   },
   machineControl: {
      group: "machine",
      title:"Machine Control",
      description: "Machine control defined here will be displayed in header if machine config not set.",
      type:"string",
    }
};

// USER ADJUSTMENTS FOR PLASMA
plasma_probedistance = 30;   // distance to probe down in Z, always in millimeters
plasma_proberate = 100;      // feedrate for probing, in mm/minute
// END OF USER ADJUSTMENTS

var debug = false;
// creation of all kinds of G-code formats - controls the amount of decimals used in the generated G-Code
var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var arcFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var feedFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:1, forceDecimal:true}); // seconds
//var taperFormat = createFormat({decimals:1, scale:DEG});

var xOutput = createVariable({prefix:"X", force:false}, xyzFormat);
var yOutput = createVariable({prefix:"Y", force:false}, xyzFormat);
var zOutput = createVariable({prefix:"Z", force:false}, xyzFormat); // dont need Z every time
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var sOutput = createVariable({prefix:"S", force:false}, rpmFormat);
var mOutput = createVariable({force:false}, mFormat); // only use for M3/4/5

// for arcs
var iOutput = createReferenceVariable({prefix:"I", force:true}, arcFormat);
var jOutput = createReferenceVariable({prefix:"J", force:true}, arcFormat);
var kOutput = createReferenceVariable({prefix:"K", force:true}, arcFormat);

var gMotionModal = createModal({}, gFormat);                                  // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat);                                  // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat);                                // modal group 5 // G93-94
var gUnitModal = createModal({}, gFormat);                                    // modal group 6 // G20-21
var gWCSOutput = createModal({}, gFormat);                                    // for G54 G55 etc

var sequenceNumber = 1;        //used for multiple file naming
var multipleToolError = false; //used for alerting during single file generation with multiple tools
var filesToGenerate = 1;       //used to figure out how many files will be generated so we can diplay in header
var minimumFeedRate = toPreciseUnit(45,MM); // GRBL lower limit in mm/minute
var fileIndexFormat = createFormat({width:2, zeropad: true, decimals:0});
var isNewfile = false;  // set true when a new file has just been started

var isLaser = false;    // set true for laser/water/
var isPlasma = false;   // set true for plasma
var power = 0;          // the setpower value, for S word when laser cutting
var cutmode = 0;        // M3 or M4
var Zmax = 0;
var workOffset = 0;
var haveRapid = false;  // assume no rapid moves
var powerOn = false;    // is the laser power on? used for laser when haveRapid=false
var retractHeight = 1;  // will be set by onParameter and used in onLinear to detect rapids
var clearanceHeight = 10;  // will be set by onParameter
var topHeight = 1;      // set by onParameter
var leadinRate = 314;   // set by onParameter: the lead-in feedrate,plasma
var linmove = 1;        // linear move mode
var toolRadius;         // for arc linearization
var plasma_pierceHeight = 1; // set by onParameter from Linking|PierceClearance
var coolantIsOn = 0;    // set when coolant is used to we can do intelligent turn off
var currentworkOffset = 54; // the current WCS in use, so we can retract Z between sections if needed


function toTitleCase(str)
   {
   // function to reformat a string to 'title case'
   return str.replace( /\w\S*/g, function(txt)
      {
      return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
      });
   }

function rpm2dial(rpm, op)
   {
   // translates an RPM for the spindle into a dial value, eg. for the Makita RT0700 and Dewalt 611 routers
   // additionally, check that spindle rpm is between minimum and maximum of what our spindle can do
   // array which maps spindle speeds to router dial settings,
   // according to Makita RT0700 Manual : 1=10000, 2=12000, 3=17000, 4=22000, 5=27000, 6=30000
   // according to Dewalt 611 Manual : 1=16000, 2=18200, 3=20400, 4=22600, 5=24800, 6=27000

   if (properties.routerType == "Dewalt")
      {
      var speeds = [0, 16000, 18200, 20400, 22600, 24800, 27000];
      }
   else if (properties.routerType == "Router11")
      {
      var speeds = [0, 10000, 14000, 18000, 23000, 27000, 32000];
      }
   else
      { // this is Makita R0701
      var speeds = [0, 10000, 12000, 17000, 22000, 27000, 30000];
      }
   if (rpm < speeds[1])
      {
      alert("Warning", rpm + " rpm is below minimum spindle RPM of " + speeds[1] + " rpm in the " + op + " operation.");
      return 1;
      }

   if (rpm > speeds[speeds.length - 1])
      {
      alert("Warning", rpm + " rpm is above maximum spindle RPM of " + speeds[speeds.length - 1] + " rpm in the " + op + " operation.");
      return (speeds.length - 1);
      }

   var i;
   for (i = 1; i < (speeds.length - 1); i++)
      {
      if ((rpm >= speeds[i]) && (rpm <= speeds[i + 1]))
         {
         return (((rpm - speeds[i]) / (speeds[i + 1] - speeds[i])) + i).toFixed(1);
         }
      }

   alert("Error", "Error in calculating router speed dial.");
   error("Fatal Error calculating router speed dial.");
   return 0;
   }

function checkMinFeedrate(section, op)
   {
   var alertMsg = "";
   if (section.getParameter("operation:tool_feedCutting") < minimumFeedRate)
      {
      var alertMsg = "Cutting\n";
      //alert("Warning", "The cutting feedrate in " + op + "  is set below the minimum feedrate that grbl supports.");
      }

   if (section.getParameter("operation:tool_feedRetract") < minimumFeedRate)
      {
      var alertMsg = alertMsg + "Retract\n";
      //alert("Warning", "The retract feedrate in " + op + "  is set below the minimum feedrate that grbl supports.");
      }

   if (section.getParameter("operation:tool_feedEntry") < minimumFeedRate)
      {
      var alertMsg = alertMsg + "Entry\n";
      //alert("Warning", "The retract feedrate in " + op + "  is set below the minimum feedrate that grbl supports.");
      }

   if (section.getParameter("operation:tool_feedExit") < minimumFeedRate)
      {
      var alertMsg = alertMsg + "Exit\n";
      //alert("Warning", "The retract feedrate in " + op + "  is set below the minimum feedrate that grbl supports.");
      }

   if (section.getParameter("operation:tool_feedRamp") < minimumFeedRate)
      {
      var alertMsg = alertMsg + "Ramp\n";
      //alert("Warning", "The retract feedrate in " + op + "  is set below the minimum feedrate that grbl supports.");
      }

   if (section.getParameter("operation:tool_feedPlunge") < minimumFeedRate)
      {
      var alertMsg = alertMsg + "Plunge\n";
      //alert("Warning", "The retract feedrate in " + op + "  is set below the minimum feedrate that grbl supports.");
      }

   if (alertMsg != "")
      {
      var fF = createFormat({decimals: 0, suffix: (unit == MM ? "mm" : "in" )});
      var fo = createVariable({}, fF);
      alert("Warning", "The following feedrates in " + op + "  are set below the minimum feedrate that GRBL supports.  The feedrate should be higher than " + fo.format(minimumFeedRate) + " per minute.\n\n" + alertMsg);
      }
   }

function writeBlock()
   {
   writeWords(arguments);
   }

/**
   Thanks to nyccnc.com
   Thanks to the Autodesk Knowledge Network for help with this at 
   https://knowledge.autodesk.com/support/hsm/learn-explore/caas/sfdcarticles/sfdcarticles/How-to-use-Manual-NC-options-to-manually-add-code-with-Fusion-360-HSM-CAM.html!
*/
function onPassThrough(text)
   {
   var commands = String(text).split(",");
   for (text in commands)
      {
      writeBlock(commands[text]);
      }
   }

function myMachineConfig()
   {
   // 3. here you can set all the properties of your machine if you havent set up a machine config in CAM.  These are optional and only used to print in the header.
   myMachine = getMachineConfiguration();
   if (!myMachine.getVendor())
      {
      // machine config not found so we'll use the info below
      myMachine.setWidth(600);
      myMachine.setDepth(800);
      myMachine.setHeight(130);
      myMachine.setMaximumSpindlePower(700);
      myMachine.setMaximumSpindleSpeed(30000);
      myMachine.setMilling(true);
      myMachine.setTurning(false);
      myMachine.setToolChanger(false);
      myMachine.setNumberOfTools(1);
      myMachine.setNumberOfWorkOffsets(6);
      myMachine.setVendor(properties.machineVendor);
      myMachine.setModel(properties.modelMachine);
      myMachine.setControl(properties.machineControl);
      }
   }

function formatComment(text)
   {
   return ("(" + filterText(String(text), permittedCommentChars) + ")");
   }

function writeComment(text)
   {
   // Remove special characters which could confuse GRBL : $, !, ~, ?, (, )
   // In order to make it simple, I replace everything which is not A-Z, 0-9, space, : , .
   // Finally put everything between () as this is the way GRBL & UGCS expect comments
   // v20 - split the line so no comment is longer than 70 chars
   if (text.length > 70)
      {
      //text = String(text).replace( /[^a-zA-Z\d:=,.]+/g, " "); // remove illegal chars
      text = formatComment(text);
      var bits = text.split(" "); // get all the words
      var out = '';
      for (i = 0; i < bits.length; i++)
         {
         out += bits[i] + " ";
         if (out.length > 60)           // a long word on the end can take us to 80 chars!
            {
            writeln("(" + out.trim() + ")");
            out = "";
            }
         }
      if (out.length > 0)
         writeln("(" + out.trim() + ")");
      }
   else
      writeln(formatComment(text));
   }

function writeHeader(secID)
   {
   //writeComment("Header start " + secID);
   if (multipleToolError)
      {
      writeComment("Warning: Multiple tools found.  This post does not support tool changes.  You should repost and select True for Multiple Files in the post properties.");
      writeln("");
      }

   var productName = getProduct();
   writeComment("Made in : " + productName);
   writeComment("G-Code optimized for " + myMachine.getControl() + " controller");
   writeComment(description);
   cpsname = FileSystem.getFilename(getConfigurationPath());
   writeComment("Post-Processor : " + cpsname + " " + obversion );
   //writeComment("Post processor documentation: " + properties.postProcessorDocs );
   var unitstr = (unit == MM) ? 'mm' : 'inch';
   writeComment("Units = " + unitstr );
   if (isJet())
      writeComment("Laser UseZ = " + properties.UseZ);

   writeln("");
   if (hasGlobalParameter("document-path"))
      {
      var path = getGlobalParameter("document-path");
      if (path)
         {
         writeComment("Drawing name : " + path);
         }
      }

   if (programName)
      {
      writeComment("Program Name : " + programName);
      }
   if (programComment)
      {
      writeComment("Program Comments : " + programComment);
      }
   writeln("");

   if (properties.generateMultiple && filesToGenerate > 1)
      {
      writeComment(numberOfSections + " Operation" + ((numberOfSections == 1) ? "" : "s") + " in " + filesToGenerate + " files.");
      writeComment("File List:");
      //writeComment("  " +  FileSystem.getFilename(getOutputPath()));
      for (var i = 0; i < filesToGenerate; ++i)
         {
         filenamePath = FileSystem.replaceExtension(getOutputPath(), fileIndexFormat.format(i + 1) + "of" + filesToGenerate + "." + extension);
         filename = FileSystem.getFilename(filenamePath);
         writeComment("  " + filename);
         }
      writeln("");
      writeComment("This is file: " + sequenceNumber + " of " + filesToGenerate);
      writeln("");
      writeComment("This file contains the following operations: ");
      }
   else
      {
      writeComment(numberOfSections + " Operation" + ((numberOfSections == 1) ? "" : "s") + " :");
      }

   for (var i = secID; i < numberOfSections; ++i)
      {
      var section = getSection(i);
      var tool = section.getTool();
      var rpm = section.getMaximumSpindleSpeed();
      isLaser = isPlasma = false;
      switch (tool.type)
         {
         case TOOL_LASER_CUTTER:
            isLaser = true;
            break;
         case TOOL_WATER_JET:
         case TOOL_PLASMA_CUTTER:
            isPlasma = true;
            break;
         default:
            isLaser = false;
            isPlasma = false;
         }

      if (section.hasParameter("operation-comment"))
         {
         writeComment((i + 1) + " : " + section.getParameter("operation-comment"));
         var op = section.getParameter("operation-comment")
         }
      else
         {
         writeComment(i + 1);
         var op = i + 1;
         }
      if (section.workOffset > 0)
         {
         writeComment("  Work Coordinate System : G" + (section.workOffset + 53));
         }
      if (isLaser || isPlasma)
         writeComment("  Tool #" + tool.number + ": " + toTitleCase(getToolTypeName(tool.type)) + " Diam = " + xyzFormat.format(tool.jetDiameter) + unitstr);
      else
         {
         writeComment("  Tool #" + tool.number + ": " + toTitleCase(getToolTypeName(tool.type)) + " " + tool.numberOfFlutes + " Flutes, Diam = " + xyzFormat.format(tool.diameter) + unitstr + ", Len = " + tool.fluteLength.toFixed(2) + unitstr);
         if (properties.routerType != "other")
            {
            writeComment("  Spindle : RPM = " + round(rpm,0) + ", set router dial to " + rpm2dial(rpm, op));
            }
         else
            {
            writeComment("  Spindle : RPM = " + round(rpm,0));
            }
         }
      checkMinFeedrate(section, op);
      var machineTimeInSeconds = section.getCycleTime();
      var machineTimeHours = Math.floor(machineTimeInSeconds / 3600);
      machineTimeInSeconds = machineTimeInSeconds % 3600;
      var machineTimeMinutes = Math.floor(machineTimeInSeconds / 60);
      var machineTimeSeconds = Math.floor(machineTimeInSeconds % 60);
      var machineTimeText = "  Machining time : ";
      if (machineTimeHours > 0)
         {
         machineTimeText = machineTimeText + machineTimeHours + " hours " + machineTimeMinutes + " min ";
         }
      else if (machineTimeMinutes > 0)
         {
         machineTimeText = machineTimeText + machineTimeMinutes + " min ";
         }
      machineTimeText = machineTimeText + machineTimeSeconds + " sec";
      writeComment(machineTimeText);

      if (properties.generateMultiple && (i + 1 < numberOfSections))
         {
         if (tool.number != getSection(i + 1).getTool().number)
            {
            writeln("");
            writeComment("Remaining operations located in additional files.");
            break;
            }
         }
      }
   if (isLaser || isPlasma)
      {
      allowHelicalMoves = false; // laser/plasma not doing this, ever
      }
   writeln("");

   gAbsIncModal.reset();
   gFeedModeModal.reset();
   gPlaneModal.reset();
   writeBlock(gAbsIncModal.format(90), gFeedModeModal.format(94), gPlaneModal.format(17) );
   switch (unit)
      {
      case IN:
         writeBlock(gUnitModal.format(20));
         break;
      case MM:
         writeBlock(gUnitModal.format(21));
         break;
      }
   //writeComment("Header end");
   writeln("");
   }

function onOpen()
   {
   if (debug) writeComment("onOpen");
   // Number of checks capturing fatal errors
   // 2. is RadiusCompensation not set incorrectly ?
   onRadiusCompensation();

   // 3. moved to top of file
   myMachineConfig();

   // 4.  checking for duplicate tool numbers with the different geometry.
   // check for duplicate tool number
   for (var i = 0; i < getNumberOfSections(); ++i)
      {
      var sectioni = getSection(i);
      var tooli = sectioni.getTool();
      if (i < (getNumberOfSections() - 1) && (tooli.number != getSection(i + 1).getTool().number))
         {
         filesToGenerate++;
         }
      for (var j = i + 1; j < getNumberOfSections(); ++j)
         {
         var sectionj = getSection(j);
         var toolj = sectionj.getTool();
         if (tooli.number == toolj.number)
            {
            if (xyzFormat.areDifferent(tooli.diameter, toolj.diameter) ||
                  xyzFormat.areDifferent(tooli.cornerRadius, toolj.cornerRadius) ||
                  abcFormat.areDifferent(tooli.taperAngle, toolj.taperAngle) ||
                  (tooli.numberOfFlutes != toolj.numberOfFlutes))
               {
               error(
                  subst(
                     localize("Using the same tool number for different cutter geometry for operation '%1' and '%2'."),
                     sectioni.hasParameter("operation-comment") ? sectioni.getParameter("operation-comment") : ("#" + (i + 1)),
                     sectionj.hasParameter("operation-comment") ? sectionj.getParameter("operation-comment") : ("#" + (j + 1))
                  )
               );
               return;
               }
            }
         else
            {
            if (properties.generateMultiple == false)
               {
               multipleToolError = true;
               }
            }
         }
      }
   if (multipleToolError)
      {
      alert("Warning", "Multiple tools found.  This post does not support tool changes.  You should repost and select True for Multiple Files in the post properties.");
      }

   numberOfSections = getNumberOfSections();
   writeHeader(0);
   gMotionModal.reset();

   if (properties.plasma_usetouchoff)
      properties.UseZ = true; // force it on, we need Z motion, always

   if (properties.UseZ)
      zOutput.format(1);
   else
      zOutput.format(0);
   //writeComment("onOpen end");
   }

function onComment(message)
   {
   writeComment(message);
   }

function forceXYZ()
   {
   xOutput.reset();
   yOutput.reset();
   zOutput.reset();
   }

function forceAny()
   {
   forceXYZ();
   feedOutput.reset();
   gMotionModal.reset();
   }

function forceAll()
   {
   //writeComment("forceAll");
   forceAny();
   sOutput.reset();
   gAbsIncModal.reset();
   gFeedModeModal.reset();
   gMotionModal.reset();
   gPlaneModal.reset();
   gUnitModal.reset();
   gWCSOutput.reset();
   mOutput.reset();
   }

// calculate the power setting for the laser
function calcPower(perc)
   {
   var PWMMin = 0;  // make it easy for users to change this
   var PWMMax = 1000;
   var v = PWMMin + (PWMMax - PWMMin) * perc / 100.0;
   return v;
   }

// go to initial position and optionally output the height check code before spindle turns on
function gotoInitial(checkit)
   {
   if (debug) writeComment("gotoInitial start");
   var sectionId = getCurrentSectionId();       // what is the number of this operation (starts from 0)
   var section = getSection(sectionId);         // what is the section-object for this operation
   var maxfeedrate = section.getMaximumFeedrate();
   // Rapid move to initial position, first XY, then Z, and do tool height check if needed
   forceAny();
   var initialPosition = getFramePosition(currentSection.getInitialPosition());
   if (isLaser || isPlasma)
      {
      f = feedOutput.format(maxfeedrate);
      checkit = false; // never do a tool height check for laser/plasma, even if the user turns it on
      }
   else
      f = "";
   writeBlock(gAbsIncModal.format(90), gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y), f);
   if (checkit)
      if ( (isNewfile || isFirstSection()) && properties.checkZ && (properties.checkFeed > 0) )
         {
         // do a Peter Stanton style Z seek and stop for a height check
         z = zOutput.format(clearanceHeight);
         f = feedOutput.format(toPreciseUnit(properties.checkFeed,MM));
         writeln("(Tool Height check https://youtu.be/WMsO24IqRKU?t=1059)");
         writeBlock(gMotionModal.format(1), z, f );
         writeBlock(mOutput.format(0));
         }
   if (debug) writeComment("gotoInitial end");
   }

// write a G53 Z retract   
function writeZretract()
   {
   zOutput.reset();
   writeln("(This relies on homing, see https://openbuilds.com/search/127200199/?q=G53+fusion )");
   writeBlock(gFormat.format(53), gMotionModal.format(0), zOutput.format(toPreciseUnit( properties.machineHomeZ, MM)));  // Retract spindle to Machine Z Home
   gMotionModal.reset();
   zOutput.reset();
   }   


function onSection()
   {
   var nmbrOfSections = getNumberOfSections();  // how many operations are there in total
   var sectionId = getCurrentSectionId();       // what is the number of this operation (starts from 0)
   var section = getSection(sectionId);         // what is the section-object for this operation
   var tool = section.getTool();
   var maxfeedrate = section.getMaximumFeedrate();
   if (debug) writeComment("onSection " + sectionId);
   haveRapid = false; // drilling sections will have rapids even when other ops do not
   
   onRadiusCompensation(); // must check every section

   if (isPlasma)
      {
      if (topHeight > plasma_pierceHeight)
         error("TOP HEIGHT MUST BE BELOW PLASMA PIERCE HEIGHT");
      if ((topHeight <= 0) && properties.plasma_usetouchoff)
         error("TOPHEIGHT MUST BE GREATER THAN 0");
      writeComment("Plasma pierce height " + plasma_pierceHeight);
      writeComment("Plasma topHeight " + topHeight);
      }

   toolRadius = tool.diameter / 2.0;

   //TODO : plasma check that top height mode is from stock top and the value is positive
   //(onParameter =operation:topHeight mode= from stock top)
   //(onParameter =operation:topHeight value= 0.8)

   if (!isFirstSection() && properties.generateMultiple && (tool.number != getPreviousSection().getTool().number))
      {
      sequenceNumber ++;
      //var fileIndexFormat = createFormat({width:3, zeropad: true, decimals:0});
      var path = FileSystem.replaceExtension(getOutputPath(), fileIndexFormat.format(sequenceNumber) + "of" + filesToGenerate + "." + extension);
      redirectToFile(path);
      forceAll();
      writeHeader(getCurrentSectionId());
      isNewfile = true;  // trigger a spindleondelay
      }
   writeln(""); // put these here so they go in the new file
   //writeComment("Section : " + (sectionId + 1) + " haveRapid " + haveRapid);

   // Insert a small comment section to identify the related G-Code in a large multi-operations file
   var comment = "Operation " + (sectionId + 1) + " of " + nmbrOfSections;
   if (hasParameter("operation-comment"))
      {
      comment = comment + " : " + getParameter("operation-comment");
      }
   writeComment(comment);
   if (debug)
      writeComment("retractHeight = " + retractHeight);
   // Write the WCS, ie. G54 or higher.. default to WCS1 / G54 if no or invalid WCS
   if (!isFirstSection() && (currentworkOffset !=  (53 + section.workOffset)) )
      {
      writeZretract();
      }
   if ((section.workOffset < 1) || (section.workOffset > 6))
      {
      alert("Warning", "Invalid Work Coordinate System. Select WCS 1..6 in SETUP:PostProcess tab. Selecting default WCS1/G54");
      //section.workOffset = 1;  // If no WCS is set (or out of range), then default to WCS1 / G54 : swarfer: this appears to be readonly
      writeBlock(gWCSOutput.format(54));  // output what we want, G54
      currentworkOffset = 54;
      }
   else
      {
      writeBlock(gWCSOutput.format(53 + section.workOffset));  // use the selected WCS
      currentworkOffset = 53 + section.workOffset;
      }
   writeBlock(gAbsIncModal.format(90));  // Set to absolute coordinates

   cutmode = -1;
   //writeComment("isMilling=" + isMilling() + "  isjet=" +isJet() + "  islaser=" + isLaser);
   switch (tool.type)
      {
      case TOOL_WATER_JET:
         writeComment("Waterjet cutting with GRBL.");
         power = calcPower(100); // always 100%
         cutmode = 3;
         isLaser = false;
         isPlasma = true;
         //writeBlock(mOutput.format(cutmode), sOutput.format(power));
         break;
      case TOOL_LASER_CUTTER:
         //writeComment("Laser cutting with GRBL.");
         isLaser = true;
         isPlasma = false;
         var pwas = power;
         switch (currentSection.jetMode)
            {
            case JET_MODE_THROUGH:
               power = calcPower(properties.PowerThrough);
               writeComment("LASER THROUGH CUTTING " + properties.PowerThrough + "percent = S" + power);
               break;
            case JET_MODE_ETCHING:
               power = calcPower(properties.PowerEtch);
               writeComment("LASER ETCH CUTTING " + properties.PowerEtch + "percent = S" + power);
               break;
            case JET_MODE_VAPORIZE:
               power = calcPower(properties.PowerVaporise);
               writeComment("LASER VAPORIZE CUTTING " + properties.PowerVaporise + "percent = S" + power);
               break;
            default:
               error(localize("Unsupported cutting mode."));
               return;
            }
         // figure cutmode, M3 or M4
         cutmode = 4; // always M4 mode
         if (pwas != power)
            {
            sOutput.reset();
            //if (isFirstSection())
            if (cutmode == 3)
               writeBlock(mOutput.format(cutmode), sOutput.format(0)); // else you get a flash before the first g0 move
            else
               writeBlock(mOutput.format(cutmode), sOutput.format(power));
            }
         break;
      case TOOL_PLASMA_CUTTER:
         writeComment("Plasma cutting with GRBL.");
         if (properties.plasma_usetouchoff)
            writeComment("Using torch height probe and pierce delay.");
         power = calcPower(100); // always 100%
         cutmode = 3;
         isLaser = false;
         isPlasma = true;
         //writeBlock(mOutput.format(cutmode), sOutput.format(power));
         break;
      default:
         //writeComment("tool.type = " + tool.type); // all milling tools
         isPlasma = isLaser = false;
         break;
      }

   if ( !isLaser && !isPlasma )
      {
      // To be safe (after jogging to whatever position), move the spindle up to a safe home position before going to the initial position
      // At end of a section, spindle is retracted to clearance height, so it is only needed on the first section
      // it is done with G53 - machine coordinates, so I put it in front of anything else
      if (isFirstSection())
         {
         writeZretract();
         }
      else if (properties.generateMultiple && (tool.number != getPreviousSection().getTool().number))
         writeZretract();

      gotoInitial(true);

      // folks might want coolant control here
      // Insert the Spindle start command
      if (tool.clockwise)
         {
         s = sOutput.format(tool.spindleRPM);
         m = mOutput.format(3);
         writeBlock(s, m);
         if (s && !m) // means a speed change, spindle was already on, delay half the time
            onDwell(properties.spindleOnOffDelay / 2);
         }
      else if (properties.spindleTwoDirections)
         {
         s = sOutput.format(tool.spindleRPM);
         m = mOutput.format(4);
         writeBlock(s, m);
         }
      else
         {
         alert("Error", "Counter-clockwise Spindle Operation found, but your spindle does not support this");
         error("Fatal Error in Operation " + (sectionId + 1) + ": Counter-clockwise Spindle Operation found, but your spindle does not support this");
         return;
         }
      // spindle on delay if needed
      if (m && (isFirstSection() || isNewfile))
         onDwell(properties.spindleOnOffDelay);

      }
   else
      {
      if (properties.UseZ)
         if (isFirstSection() || (properties.generateMultiple && (tool.number != getPreviousSection().getTool().number)) )
            {
            writeZretract();
            gotoInitial(false);
            }
      }


   forceXYZ();

   var remaining = currentSection.workPlane;
   if (!isSameDirection(remaining.forward, new Vector(0, 0, 1)))
      {
      alert("Error", "Tool-Rotation detected - GRBL only supports 3 Axis");
      error("Fatal Error in Operation " + (sectionId + 1) + ": Tool-Rotation detected but GRBL only supports 3 Axis");
      }
   setRotation(remaining);

   forceAny();


   // If the machine has coolant, write M8/M7 or M9
   if (properties.hasCoolant)
      {
      if (isLaser || isPlasma)
         setCoolant(1) // always turn it on since plasma tool has no coolant option in fusion
         else
            setCoolant(tool.coolant); // use tool setting
      }

   if (isLaser && properties.UseZ)
      writeBlock(gMotionModal.format(0), zOutput.format(0));
   isNewfile = false;
   //writeComment("onSection end");
   }

function onDwell(seconds)
   {
   if (seconds > 0.0)
      writeBlock(gFormat.format(4), "P" + secFormat.format(seconds));
   }

function onSpindleSpeed(spindleSpeed)
   {
   writeBlock(sOutput.format(spindleSpeed));
   gMotionModal.reset(); // force a G word after a spindle speed change to keep CONTROL happy
   }

function onRadiusCompensation()
   {
   var radComp = getRadiusCompensation();
   var sectionId = getCurrentSectionId();
   if (radComp != RADIUS_COMPENSATION_OFF)
      {
      alert("Error", "RadiusCompensation is not supported in GRBL - Change RadiusCompensation in CAD/CAM software to Off/Center/Computer");
      error("Fatal Error in Operation " + (sectionId + 1) + ": RadiusCompensation is found in CAD file but is not supported in GRBL");
      return;
      }
   }

function onRapid(_x, _y, _z)
   {
   haveRapid = true;
   if (debug) writeComment("onRapid");
   if (!isLaser && !isPlasma)
      {
      var x = xOutput.format(_x);
      var y = yOutput.format(_y);
      var z = zOutput.format(_z);

      if (x || y || z)
         {
         writeBlock(gMotionModal.format(0), x, y, z);
         feedOutput.reset();
         }
      }
   else
      {
      if (_z > Zmax) // store max z value for ending
         Zmax = _z;
      var x = xOutput.format(_x);
      var y = yOutput.format(_y);
      var z = "";
      if (isPlasma && properties.UseZ)  // laser does not move Z during cuts
         {
         z = zOutput.format(_z);
         }
      if (isPlasma && properties.UseZ && (xyzFormat.format(_z) == xyzFormat.format(topHeight)) )
         {
         if (debug) writeComment("onRapid skipping Z motion");
         if (x || y)
            writeBlock(gMotionModal.format(0), x, y);
         zOutput.reset();   // force it on next command
         }
      else if (x || y || z)
         writeBlock(gMotionModal.format(0), x, y, z);
      }
   }

function onLinear(_x, _y, _z, feed)
   {
   //if (debug) writeComment("onLinear " + haveRapid);   
   if (powerOn || haveRapid)   // do not reset if power is off - for laser G0 moves
      {
      xOutput.reset();
      yOutput.reset(); // always output x and y else arcs go mad
      }
   var x = xOutput.format(_x);
   var y = yOutput.format(_y);
   var f = feedOutput.format(feed);
   if (!isLaser && !isPlasma)
      {
      var z = zOutput.format(_z);

      if (x || y || z)
         {
         linmove = 1;          // have to have a default!
         if (!haveRapid && z)  // if z is changing
            {
            if (_z < retractHeight) // compare it to retractHeight, below that is G1, >= is G0
               linmove = 1;
            else
               linmove = 0;
            if (debug && (linmove == 0)) writeComment("NOrapid");
            }
         writeBlock(gMotionModal.format(linmove), x, y, z, f);
         }
      else if (f)
         {
         if (getNextRecord().isMotion())
            {
            feedOutput.reset(); // force feed on next line
            }
         else
            {
            writeBlock(gMotionModal.format(1), f);
            }
         }
      }
   else
      {
      // laser, plasma
      if (x || y)
         {
         if (haveRapid)
            {
            // this is the old process when we have rapids inserted by onRapid
            var z = properties.UseZ ? zOutput.format(_z) : "";
            var s = sOutput.format(power);
            if (isPlasma && !powerOn) // plasma does some odd routing that should be rapid
               writeBlock(gMotionModal.format(0), x, y, z, f, s);
            else
               writeBlock(gMotionModal.format(1), x, y, z, f, s);
            }
         else
            {
            // this is the new process when we dont have onRapid but GRBL requires G0 moves for noncutting laser moves
            var z = properties.UseZ ? zOutput.format(0) : "";
            var s = sOutput.format(power);
            if (powerOn)
               writeBlock(gMotionModal.format(1), x, y, z, f, s);
            else
               writeBlock(gMotionModal.format(0), x, y, z, f, s);
            }

         }
      }
   }

function onRapid5D(_x, _y, _z, _a, _b, _c)
   {
   alert("Error", "Tool-Rotation detected - GRBL only supports 3 Axis");
   error("Tool-Rotation detected but GRBL only supports 3 Axis");
   }

function onLinear5D(_x, _y, _z, _a, _b, _c, feed)
   {
   alert("Error", "Tool-Rotation detected - GRBL only supports 3 Axis");
   error("Tool-Rotation detected but GRBL only supports 3 Axis");
   }

function onCircular(clockwise, cx, cy, cz, x, y, z, feed)
   {
   var start = getCurrentPosition();
   xOutput.reset(); // always have X and Y, Z will output of it changed
   yOutput.reset();

   // arcs smaller than bitradius always have significant radius errors, so get radius and linearize them (because we cannot change minimumCircularRadius here)
   // note that larger arcs still have radius errors, but they are a much smaller percentage of the radius
   var rad = Math.sqrt(Math.pow(start.x - cx,2) + Math.pow(start.y - cy, 2));
   if (properties.linearizeSmallArcs &&  (rad < toolRadius))
      {
      //writeComment("linearizing arc radius " + round(rad,4) + " toolRadius " + round(toolRadius,3));
      linearize(tolerance);
      return;
      }
   if (isFullCircle())
      {
      writeComment("full circle");
      linearize(tolerance);
      return;
      }
   else
      {
      if (isPlasma && !powerOn)
         linearize(tolerance * 4); // this is a rapid move so tolerance can be increased for faster motion and fewer lines of code
      else
         switch (getCircularPlane())
            {
            case PLANE_XY:
               if (!isLaser && !isPlasma)
                  writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
               else
                  {
                  zo = properties.UseZ ? zOutput.format(z) : "";
                  writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zo, iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
                  }
               break;
            case PLANE_ZX:
               if (!isLaser)
                  writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
               else
                  linearize(tolerance);
               break;
            case PLANE_YZ:
               if (!isLaser)
                  writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
               else
                  linearize(tolerance);
               break;
            default:
               linearize(tolerance);
            }
      }
   }

function onSectionEnd()
   {
   writeln("");
   // writeBlock(gPlaneModal.format(17));
   if (isRedirecting())
      {
      if (!isLastSection() && properties.generateMultiple && (tool.number != getNextSection().getTool().number) || (isLastSection() && !isFirstSection()))
         {
         writeln("");
         onClose();
         closeRedirection();
         }
      }
   //if (properties.hasCoolant)
   //   setCoolant(0);
   forceAny();
   }

function onClose()
   {
   writeBlock(gAbsIncModal.format(90));   // Set to absolute coordinates for the following moves
   if (!isLaser && !isPlasma)
      {
      gMotionModal.reset();  // for ease of reading the code always output the G0 words
      writeZretract();
      //writeBlock(gAbsIncModal.format(90), gFormat.format(53), gMotionModal.format(0), "Z" + xyzFormat.format(toPreciseUnit(properties.machineHomeZ, MM)));  // Retract spindle to Machine Z Home
      }
   writeBlock(mFormat.format(5));                              // Stop Spindle
   if (properties.hasCoolant)
      {
      setCoolant(0);                           // Stop Coolant
      }
   //onDwell(properties.spindleOnOffDelay);                    // Wait for spindle to stop
   gMotionModal.reset();
   if (!isLaser && !isPlasma)
      {
      if (properties.gotoMCSatend)    // go to MCS home
         {
         writeBlock(gAbsIncModal.format(90), gFormat.format(53), gMotionModal.format(0),
                    "X" + xyzFormat.format(toPreciseUnit(properties.machineHomeX, MM)),
                    "Y" + xyzFormat.format(toPreciseUnit(properties.machineHomeY, MM)));
         }
      else      // go to WCS home
         {
         writeBlock(gAbsIncModal.format(90), gMotionModal.format(0),
                    "X" + xyzFormat.format(toPreciseUnit(properties.machineHomeX, MM)),
                    "Y" + xyzFormat.format(toPreciseUnit(properties.machineHomeY, MM)));
         }
      }
   else     // laser
      {
      if (properties.UseZ)
         {
         if (isLaser)
            writeBlock( gAbsIncModal.format(90), gFormat.format(53),
                        gMotionModal.format(0), zOutput.format(toPreciseUnit(properties.machineHomeZ, MM)) );
         if (isPlasma)
            {
            xOutput.reset();
            yOutput.reset();
            if (properties.gotoMCSatend)    // go to MCS home
               {
               writeBlock( gAbsIncModal.format(90), gFormat.format(53),
                           gMotionModal.format(0),
                           zOutput.format(toPreciseUnit(properties.machineHomeZ, MM)) );
               writeBlock( gAbsIncModal.format(90), gFormat.format(53),
                           gMotionModal.format(0),
                           xOutput.format(toPreciseUnit(properties.machineHomeX, MM)),
                           yOutput.format(toPreciseUnit(properties.machineHomeY, MM)) );
               }
            else
               writeBlock(gMotionModal.format(0), xOutput.format(0), yOutput.format(0));
            }
         }
      }
   writeBlock(mFormat.format(30));  // Program End
   //writeln("%");                    // EndOfFile marker
   }

function onTerminate()
   {
   // If we are generating multiple files, then rename first file to add # of #
   // If you dont want to show the log file, then untick "open in Open file in NC editor"
   if (filesToGenerate > 1) {
     var fileIndexFormat = createFormat({ width: 2, zeropad: true, decimals: 0 });
     var newOutput = FileSystem.replaceExtension(getOutputPath(), fileIndexFormat.format(1) + 'of' + filesToGenerate + '.' + extension);
     FileSystem.moveFile(getOutputPath(), newOutput);
     executeNoWait(newOutput, '', false, '');
    }
   }

function onCommand(command)
   {
   if (debug ) writeComment("onCommand " + command);
   switch (command)
      {
      case COMMAND_STOP: // - Program stop (M00)
         writeComment("Program stop (M00)");
         writeBlock(mFormat.format(0));
         break;
      case COMMAND_OPTIONAL_STOP: // - Optional program stop (M01)
         writeComment("Optional program stop (M01)");
         writeBlock(mFormat.format(1));
         break;
      case COMMAND_END: // - Program end (M02)
         writeComment("Program end (M02)");
         writeBlock(mFormat.format(2));
         break;
      case COMMAND_POWER_OFF:
         //writeComment("power off");
         if (!haveRapid)
            writeln("");
         powerOn = false;
         if (isPlasma)
            writeBlock(mFormat.format(5));
         break;
      case COMMAND_POWER_ON:
         //writeComment("power ON");
         if (!haveRapid)
            writeln("");
         powerOn = true;
         if (isPlasma)
            {
            if (properties.UseZ)
               {
               if (properties.plasma_usetouchoff)
                  {
                  writeln("");
                  writeBlock( "G38.2" , zOutput.format(toPreciseUnit(-plasma_probedistance,MM)), feedOutput.format(toPreciseUnit(plasma_proberate,MM)));
                  if (debug) writeComment("touch offset "  + xyzFormat.format(properties.plasma_touchoffOffset) );
                  writeBlock( gMotionModal.format(10), "L20" , zOutput.format(toPreciseUnit(-properties.plasma_touchoffOffset,MM)) );
                  feedOutput.reset();
                  }
               // move to pierce height
               if (debug)
                  writeBlock( gMotionModal.format(0), zOutput.format(plasma_pierceHeight) , " ; pierce height" );
               else
                  writeBlock( gMotionModal.format(0), zOutput.format(plasma_pierceHeight));
               }
            writeBlock(mFormat.format(3), sOutput.format(power));
            }
         break;
      }
   // for other commands see https://cam.autodesk.com/posts/reference/classPostProcessor.html#af3a71236d7fe350fd33bdc14b0c7a4c6
   if (debug) writeComment("onCommand end");
   }

function onParameter(name, value)
   {
   //if (debug) writeComment("onParameter =" + name + "= " + value);   // (onParameter =operation:retractHeight value= :5)
   name = name.replace(" ","_");  // dratted indexOF cannot have spaces in it!
   if ( (name.indexOf("retractHeight_value") >= 0 ) )   // == "operation:retractHeight value")
      {
      retractHeight = value;
      if (debug) writeComment("retractHeight = "+retractHeight);
      }
   if (name.indexOf("operation:clearanceHeight_value") >= 0)
      {
      clearanceHeight = value;
      if (debug) writeComment("clearanceHeight = "+clearanceHeight);
      }

   if (name.indexOf("movement:lead_in") !== -1)
      {
      leadinRate = value;
      if (debug && isPlasma) writeComment("leadinRate set " + leadinRate);
      }

   if (name.indexOf("operation:topHeight_value") >= 0)
      {
      topHeight = value;
      if (debug && isPlasma) writeComment("topHeight set " + topHeight);
      }
   // (onParameter =operation:pierceClearance= 1.5)    for plasma
   if (name == 'operation:pierceClearance')
      plasma_pierceHeight = value;
   if ((name == 'action') && (value == 'pierce'))
      {
      if (debug) writeComment('action pierce');
      onDwell(properties.spindleOnOffDelay);
      if (properties.UseZ) // done a probe and/or pierce, now lower to cut height
         {
         writeBlock( gMotionModal.format(1) , zOutput.format(topHeight) , feedOutput.format(leadinRate) );
         gMotionModal.reset();
         }
      }
   }

function round(num,digits)
   {
   return toFixedNumber(num,digits,10)
   }

function toFixedNumber(num, digits, base)
   {
   var pow = Math.pow(base||10, digits);  // cleverness found on web
   return Math.round(num*pow) / pow;
   }

// set the coolant mode from the tool value
function setCoolant(coolval)
   {
   if ( debug) writeComment("setCoolant " + coolval);
   // 0 if off, 1 is flood, 2 is mist, 7 is both
   switch (coolval)
      {
      case 0:
         if (coolantIsOn != 0)
            writeBlock(mFormat.format(9)); // off
         coolantIsOn = 0;
         break;
      case 1:
         if (coolantIsOn == 2)
            writeBlock(mFormat.format(9)); // turn mist off
         writeBlock(mFormat.format(8)); // flood
         coolantIsOn = 1;
         break;
      case 2:
         writeComment("Mist coolant on pin A3. special GRBL compile for this.");
         if (coolantIsOn == 1)
            writeBlock(mFormat.format(9)); // turn flood off
         writeBlock(mFormat.format(7)); // mist
         coolantIsOn = 2;
         break;
      case 7:  // flood and mist
         writeBlock(mFormat.format(8)); // flood
         writeBlock(mFormat.format(7)); // mist
         coolantIsOn = 7;
         break;
      default:
         writeComment("Coolant option not understood: " + coolval);
         alert("Warning", "Coolant option not understood: " + coolval);
         coolantIsOn = 0;
      }
   if ( debug) writeComment("setCoolant end");
   }
