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
   10 May 2022 - V1.0.30 : Change naming convention for first file in multifile output (Sharmstr)
   xx Sep 2022 - V1.0.31 : better laser, with pierce option if cutting
   06 Dec 2022 - V1.0.32 : fix long comments that were getting extra brackets
   22 Dec 2022 - V1.0.33 : refactored file naming and debugging, indented with astyle
   10 Mar 2023 - V1.0.34 : move coolant code to the spindle control line to help with restarts
   26 Mar 2023 - V1.0.35 : plasma pierce height override,  spindle speed change always with an M3, version number display
   03 Jun 2023 - V1.0.36 : code to recenter arcs with bad radii
   04 Oct 2023 - V1.0.37 : Tape splitting
      Nov 2023 - V1.0.38 : Simple probing, each axis on its own, and xy corner, for BB4x with 3D probe, and machine simulation
   10 Feb 3024 - V1.0.39 : Add missing drill cycles, missing because probing failed to expand unhandled cycles
   13 Mar 2024 - V1.0.40 : force position after plasma probe, fix plasma linearization of small arcs to avoid GRBL bug in arc after probe, fix pierceClearance and pierceHeight, fix plasma kerfWidth
   27 Mar 2024 - V1.0.41 : replace 'power' with OB.power (and friends) because postprocessor.power now exists and is readonly
   30 Mar 2024 - V1.0.42 : postprocessor.alert() method has disappeared - replaced with warning(msg) and writeComment(msg), moved more stuff into OB. and SPL.
   xx Oct 2024 - V1.0.43 : fix plasma pierce/cut height, pierceTime so it uses the tool settings if provided
   10 Aug 2025 - V1.0.44 : fix movement ordering and other tweaks, see readme.md
   17 Aug 2025 - V1.0.45 : docs, refactored, new speed handling in adaptives, see README for details
   25 Dec 2025 - V1.0.46 : wcs handling on sections, plasma arcs, direct moves, linesplit feedrate on reentry, total machining time in header
*/
obversion = 'V1.0.46';
description = "OpenBuilds CNC : GRBL/BlackBox";  // cannot have brackets in comments
longDescription = description + " : Post " + obversion; // adds description to post library dialog box
vendor = "OpenBuilds";
vendorUrl = "https://openbuilds.com";
model = "GRBL";
legal = "Copyright Openbuilds and swarfer 2025";
certificationLevel = 2;
minimumRevision = 45892;

debugMode = false;

extension = "gcode";                            // file extension of the gcode file
setCodePage("ascii");                           // character set of the gcode file
//setEOL(CRLF);                                 // end-of-line type : use CRLF for windows

var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,=_-*/\\:";
capabilities = CAPABILITY_MILLING | CAPABILITY_JET | CAPABILITY_INSPECTION | CAPABILITY_MACHINE_SIMULATION;      // intended for a CNC, so Milling, and waterjet/plasma/laser
tolerance = spatial(0.002, MM);
minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.125, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.1); // was 0.01
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowSpiralMoves = false;
allowedCircularPlanes = (1 << PLANE_XY); // allow only XY plane
// if you need vertical arcs then uncomment the line below
//allowedCircularPlanes = (1 << PLANE_XY) | (1 << PLANE_ZX) | (1 << PLANE_YZ); // allow all planes, recentering arcs solves YZ/XZ arcs
// if you allow vertical arcs then be aware that ObCONTROL will not display the gcode correctly, but it WILL cut correctly.

/**
 * @typedef {object} SplittingState
 * @property {number} tapelines - The maximum number of G-code lines allowed per file before a split is triggered. A value of 0 disables splitting by line count. This is set from the `splitLines` post-processor property.
 * @property {number} linecnt - The current line counter for the active file. It is incremented with each call to `writeBlock`.
 * @property {boolean} forceSplit - A flag that, when set to true, forces a file split at the beginning of the next section. This is used to signal that the line count has been exceeded.
 */

/**
 * Manages the state for splitting G-code files based on line count ("tape splitting").
 * This object holds the configuration and current status for the file splitting logic.
 * Note that line counts will not be exact as we try to split at the next rapid movement 
 * after linecount has been achieved.
 * @type {SplittingState}
 */
var SPL = 
   {
   tapelines : 0,
   linecnt : 0,
   forceSplit : false
   }

// user-defined properties : defaults are set, but they can be changed from a dialog box in Fusion when doing a post.
properties =
   {
   spindleOnOffDelay: 1.8,        // time (in seconds) the spindle needs to get up to speed or stop, or laser/plasma pierce delay
   spindleTwoDirections : false,  // true : spindle can rotate clockwise and counterclockwise, will send M3 and M4. false : spindle can only go clockwise, will only send M3
   hasCoolant : false,            // true : machine uses the coolant output, M8 M9 will be sent. false : coolant output not connected, so no M8 M9 will be sent
   routerType : "other",
   generateMultiple: true,        // specifies if a file should be generated for each tool change
   splitLines: 0,                 // if > 0 then split on line count (and tool change if that is also set)
   machineHomeZ : -10,            // absolute machine coordinates where the machine will move to at the end of the job - first retracting Z, then moving home X Y
   machineHomeX : -10,            // always in millimeters
   machineHomeY : -10,
   gotoMCSatend : false,          // true will do G53 G0 x{machinehomeX} y{machinehomeY}, false will do G0 x{machinehomeX} y{machinehomeY} at end of program
   PowerVaporise : 5,         // cutting power in percent, to vaporize plastic coatings
   PowerThrough  : 100,       // for through cutting
   PowerEtch     : 10,        // for etching the surface
   UseZ : false,           // if true then Z will be moved to 0 at beginning and back to 'retract height' at end
   UsePierce : false,      // if true && islaser && cutting use M3 and honor pierce delays, else use M4
   //plasma stuff
   plasma_usetouchoff : false,                        // use probe for touchoff if true
   plasma_touchoffOffset : 5.0,                       // offset from trigger point to real Z0, used in G10 line
   plasma_pierceHeightoverride: false,                // if true replace all pierce height settings with value below
   plasma_pierceHeightValue : toPreciseUnit(10,MM), //mmOrInch(10, 0.375),    // not forcing mm, user beware
   plasma_postcutdelay : 0,                           // seconds to delay after the cut stops to allow assist air to bleed off

   linearizeSmallArcs: true,     // arcs with radius < toolRadius have radius errors, linearize instead?
   machineVendor : "OpenBuilds",
   modelMachine : "Generic XYZ",
   machineControl : "Grbl 1.1 / BlackBox",

   checkZ : false,    // true for a PS tool height checkmove at start of every file
   checkFeed : 200    // always MM/min
   //postProcessorDocs : 'https://docs.openbuilds.com/doku.php', // for future use.  link to post processor help docs.  be sure to uncomment comment as well
   };

// user-defined property definitions - note, do not skip any group numbers
groupDefinitions =
   {
   //postInfo: {title: "OpenBuilds Post Documentation: https://docs.openbuilds.com/doku.php", description: "", order: 0},
   spindle: {title: "Spindle/Plasma", description: "Spindle and Plasma Cutter options", order: 1},
   safety: {title: "Safety", description: "Safety options", order: 2},
   toolChange: {title: "Tool Changes", description: "Tool change options", order: 3},
   startEndPos: {title: "Job Start Z and Job End X,Y,Z Coordinates", description: "Set the spindle start and end position", order: 4},
   arcs: {title: "Arcs", description: "Arc options", order: 5},
   laserPlasma: {title: "Laser / Plasma", description: "Laser / Plasma options", order: 6},
   machine: {title: "Machine", description: "Machine options", order: 7}
   };
propertyDefinitions =
   {
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
      values: [
         {title:"Other", id:"other"},
         {title: "Router11", id: "Router11"},
         {title: "Makita RT0701", id: "Makita"},
         {title: "Dewalt 611", id: "Dewalt"}
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
      title: "SPINDLE on/off or Plasma Pierce Delay",
      description: "Time (in seconds) the spindle needs to get up to speed or stop, also used for plasma pierce delay if > 0, else uses tool.pierceTime",
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
      title: "TOOL: Generate muliple files for tool changes?",
      description: "Generate multiple files. One for each tool change.",
      type: "boolean",
      },
   splitLines:  {
         group: "toolChange",
         title: "Split on line count (0 for none)",
         description: "Split files after given number of lines, or 0 for no split on line count.",
         type: "number",
         },      

   gotoMCSatend: {
      group: "startEndPos",
      title: "EndPos: Use Machine Coordinates (G53) at end of job?",
      description: "Yes will do G53 G0 x{machinehomeX} y(machinehomeY) (Machine Coordinates), No will do G0 x(machinehomeX) y(machinehomeY) (Work Coordinates) at end of program",
      type: "boolean",
      },
   machineHomeX: {
      group: "startEndPos",
      title: "EndPos: End of job X position (MM).",
      description: "(G53 or G54) X position to move to in Millimeters",
      type: "spatial",
      },
   machineHomeY: {
      group: "startEndPos",
      title: "EndPos: End of job Y position (MM).",
      description: "(G53 or G54) Y position to move to in Millimeters.",
      type: "spatial",
      },
   machineHomeZ: {
      group: "startEndPos",
      title: "startEndPos: START and End of job Z position (MCS Only) (MM)",
      description: "G53 Z position to move to in Millimeters, normally negative.  Moves to this distance below Z home.",
      type: "spatial",
      },

   linearizeSmallArcs: {
      group: "arcs",
      title: "ARCS: Linearize Small Arcs",
      description: "Arcs with radius &lt; toolRadius can have mismatched radii, set this to Yes to linearize them. This solves G2/G3 radius mismatch errors.",
      type: "boolean",
      },

   PowerVaporise: {title: "LASER: Power for Vaporizing", description: "Just enough Power to VAPORIZE plastic coating, in percent.", group: "laserPlasma", type: "integer"},
   PowerThrough:  {title: "LASER: Power for Through Cutting", description: "Normal Through cutting power, in percent.", group: "laserPlasma", type: "integer"},
   PowerEtch:     {title: "LASER: Power for Etching", description: "Just enough power to Etch the surface, in percent.", group: "laserPlasma", type: "integer"},
   UseZ:          {title: "P+L: Use Z motions at start and end.", description: "Use True if you have a laser on a router with Z motion, or a PLASMA cutter.", group: "laserPlasma", type: "boolean"},
   UsePierce:     {title: "LASER: Use pierce delays with M3 motion when cutting.", description: "True will use M3 commands and pierce delays, else use M4 with no delays.", group: "laserPlasma", type: "boolean"},
   plasma_usetouchoff:  {title: "PLASMA: Use Z touchoff probe routine", description: "Set to true if have a touchoff probe for Plasma.", group: "laserPlasma", type: "boolean"},
   plasma_touchoffOffset: {title: "PLASMA: Plasma touch probe offset", description: "Offset in Z at which the probe triggers, always Millimeters, always positive.", group: "laserPlasma", type: "spatial"},
   plasma_pierceHeightoverride: {title: "P+L: Override the pierce height", description: "Set to true if want to always use the pierce height Z value.", group: "laserPlasma", type: "boolean"},
   plasma_pierceHeightValue : {title: "P+L: Override the pierce height Z value", description: "Offset in Z for the plasma pierce height, always positive. Set to 0 to avoid all piercing.", group: "laserPlasma", type: "spatial"},
   plasma_postcutdelay : {title: "PLASMA: Seconds to delay after cut", description: "Seconds to delay after cut stops to allow assist air to bleed off before next pierce.", group: "laserPlasma", type: "number"},

   machineVendor: {
      group: "machine",
      title: "Machine Vendor",
      description: "Machine vendor defined here will be displayed in header if machine config not set.",
      type: "string",
      },
   modelMachine: {
      group: "machine",
      title: "Machine Model",
      description: "Machine model defined here will be displayed in header if machine config not set.",
      type: "string",
      },
   machineControl: {
      group: "machine",
      title: "Machine Control",
      description: "Machine control defined here will be displayed in header if machine config not set.",
      type: "string",
      }
   };

// USER ADJUSTMENTS FOR PLASMA
plasma_probedistance = 15;   // distance to probe down in Z, always in millimeters
plasma_proberate = 100;      // feedrate for probing, in mm/minute
// END OF USER ADJUSTMENTS


// creation of all kinds of G-code formats - controls the amount of decimals used in the generated G-Code
var gFormat = createFormat({prefix: "G", decimals: 0});
var gPFormat = createFormat({prefix: "G", decimals: 1}); // for probing commands
var mFormat = createFormat({prefix: "M", decimals: 0});

var xyzFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var abcFormat = createFormat({decimals: 3, forceDecimal: true, scale: DEG});
var arcFormat = createFormat({decimals: (unit == MM ? 3 : 4)});
var feedFormat = createFormat({decimals: 0});
var rpmFormat = createFormat({decimals: 0});
var pFormat = createFormat({decimals: 0});
var secFormat = createFormat({decimals: 3, forceDecimal: true}); // seconds
//var taperFormat = createFormat({decimals:1, scale:DEG});

var xOutput = createVariable({prefix: "X", force: false}, xyzFormat);
var yOutput = createVariable({prefix: "Y", force: false}, xyzFormat);
var zOutput = createVariable({prefix: "Z", force: false}, xyzFormat); // dont need Z every time
var feedOutput = createVariable({prefix: "F"}, feedFormat);
var sOutput = createVariable({prefix: "S", force: false}, rpmFormat);
var pWord = createVariable({prefix: "P", force: true}, pFormat);
var mOutput = createVariable({force: false}, mFormat); // only use for M3/4/5

// for arcs
var iOutput = createReferenceVariable({prefix: "I", force: true}, arcFormat);
var jOutput = createReferenceVariable({prefix: "J", force: true}, arcFormat);
var kOutput = createReferenceVariable({prefix: "K", force: true}, arcFormat);

var gMotionModal = createModal({}, gFormat);                                  // modal group 1 // G0-G3, ...
var gProbeModal = createModal({onchange: function ()  { gMotionModal.reset(); }, force: true }, gPFormat);                                  
var gPlaneModal = createModal({onchange: function ()
   {
   gMotionModal.reset();
   }
                              }, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat);                                  // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat);                                // modal group 5 // G93-94
var gUnitModal = createModal({}, gFormat);                                    // modal group 6 // G20-21
var gWCSOutput = createModal({}, gFormat);                                    // for G54 G55 etc

var sequenceNumber = 1;        //used for multiple file naming
var multipleToolError = false; //used for alerting during single file generation with multiple tools
var filesToGenerate = 1;       //used to figure out how many files will be generated so we can diplay in header
var minimumFeedRate = toPreciseUnit(45, MM); // GRBL lower limit in mm/minute
var fileIndexFormat = createFormat({width: 2, zeropad: true, decimals: 0});
var isNewfile = false;  // set true when a new file has just been started

// group our private variables together so Autodesk does not break us when they make something into a property
var OB = {
   power : 0,           // the setpower value, for S word when laser/plasma cutting
   powerOn : false,     // is the laser power on? used for laser when haveRapid=false
   isLaser : false,     // set true for laser/water/
   isPlasma : false,    // set true for plasma
   isMill : false,      // set true for mill and not laser and not plasma
   cutmode :  0,        // M3 or M4
   cuttingMode : 'none',  // set by onParameter for laser/plasma
   haveRapid : false,   // assume no rapid moves
   movestr : 'unknown',  // movement type string for comments
   movestrP : 'unknown'  // movement type string for comments
}

/**
 * @typedef {object} HeightsState
 * @property {number} retract - The Z-height to which the tool retracts during linking moves.
 * @property {number} clearance - A safe Z-height used for initial positioning and tool checks.
 * @property {number} top - The top height of the current operation, often used as a reference for plasma/laser cut heights.
 */
/**
 * Manages the various height settings received from Fusion 360 operations.
 * @type {HeightsState}
 */
var Heights = {
   retract: 1,    // will be set by onParameter and used in onLinear to detect rapids
   clearance: 10, // will be set by onParameter
   top: 1         // set by onParameter
   };

/*
   Keep track of feedrates, saved here by onParameter
*/        
var Feeds = {
   cutting: 1,    // cutting feedrate
   entry : 1,     // lead-in feedrate
   exit : 1       // lead-out feedrate 
   }

var plasma = {
   pierceHeight : 3.14, // set by onParameter or tool.pierceHeight
   pierceTime : 3.14,   // plasma pierce delay set by tool if properties.spindleOnOffDelay = 0
   leadinRate : 314,    // set by onParameter: the lead-in feedrate,plasma : onparameter:movement:lead_in is always metric so convert when needed
   cutHeight : 3.14,    // tool cut height from onParameter
   mode : 1             // mode 1 is the old mode using topHeights as cutheight, mode 2 is new mode, using tool cutheight
   };

//var workOffset = 0;
//var retractHeight = 1;     // will be set by onParameter and used in onLinear to detect rapids
//var clearanceHeight = 10;  // will be set by onParameter
//var topHeight = 1;         // set by onParameter
var linmove = 1;           // linear move mode
var toolRadius;            // for arc linearization
var coolantIsOn = 0;       // set when coolant is used to we can do intelligent turn off
var currentworkOffset = 0; // the current WCS in use, so we can retract Z between sections if needed
var clnt = '';             // coolant code to add to spindle line

var PRB = {
   feedProbeLink : 1000,         // probe linking moves feedrate
   feedProbeMeasure : 102,       // probing feedrate
   probe_output_work_offset : 0  // the WCS to update when probing
   }

// Start of machine configuration logic
var compensateToolLength = false; // add the tool length to the pivot distance for nonTCP rotary heads

// internal variables, do not change
var receivedMachineConfiguration;
var operationSupportsTCP;
var multiAxisFeedrate;

function activateMachine() {
  // disable unsupported rotary axes output
  if (!machineConfiguration.isMachineCoordinate(0) && (typeof aOutput != "undefined")) {
    aOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(1) && (typeof bOutput != "undefined")) {
    bOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(2) && (typeof cOutput != "undefined")) {
    cOutput.disable();
  //machineConfiguration.setControl(properties.machineControl);
  }

  // setup usage of multiAxisFeatures
  useMultiAxisFeatures = getProperty("useMultiAxisFeatures") != undefined ? getProperty("useMultiAxisFeatures") :
    (typeof useMultiAxisFeatures != "undefined" ? useMultiAxisFeatures : false);
  useABCPrepositioning = getProperty("useABCPrepositioning") != undefined ? getProperty("useABCPrepositioning") :
    (typeof useABCPrepositioning != "undefined" ? useABCPrepositioning : false);

  if (!machineConfiguration.isMultiAxisConfiguration()) {
    return; // don't need to modify any settings for 3-axis machines
  }

  // save multi-axis feedrate settings from machine configuration
  var mode = machineConfiguration.getMultiAxisFeedrateMode();
  var type = mode == FEED_INVERSE_TIME ? machineConfiguration.getMultiAxisFeedrateInverseTimeUnits() :
      (mode == FEED_DPM ? machineConfiguration.getMultiAxisFeedrateDPMType() : DPM_STANDARD);
  multiAxisFeedrate = {
    mode     : mode,
    maximum  : machineConfiguration.getMultiAxisFeedrateMaximum(),
    type     : type,
    tolerance: mode == FEED_DPM ? machineConfiguration.getMultiAxisFeedrateOutputTolerance() : 0,
    bpwRatio : mode == FEED_DPM ? machineConfiguration.getMultiAxisFeedrateBpwRatio() : 1
  };

  // setup of retract/reconfigure  TAG: Only needed until post kernel supports these machine config settings
  if (receivedMachineConfiguration && machineConfiguration.performRewinds()) {
    safeRetractDistance = machineConfiguration.getSafeRetractDistance();
    safePlungeFeed = machineConfiguration.getSafePlungeFeedrate();
    safeRetractFeed = machineConfiguration.getSafeRetractFeedrate();
  }
  if (typeof safeRetractDistance == "number" && getProperty("safeRetractDistance") != undefined && getProperty("safeRetractDistance") != 0) {
    safeRetractDistance = getProperty("safeRetractDistance");
  }

  if (machineConfiguration.isHeadConfiguration()) {
    compensateToolLength = typeof compensateToolLength == "undefined" ? false : compensateToolLength;
  }

  if (machineConfiguration.isHeadConfiguration() && compensateToolLength) {
    for (var i = 0; i < getNumberOfSections(); ++i) {
      var section = getSection(i);
      if (section.isMultiAxis()) {
        machineConfiguration.setToolLength(getBodyLength(section.getTool())); // define the tool length for head adjustments
        section.optimizeMachineAnglesByMachine(machineConfiguration, OPTIMIZE_AXIS);
      }
    }
  } else {
    optimizeMachineAngles2(OPTIMIZE_AXIS);
  }
}

function getBodyLength(tool) {
  for (var i = 0; i < getNumberOfSections(); ++i) {
    var section = getSection(i);
    if (tool.number == section.getTool().number) {
      return section.getParameter("operation:tool_overallLength", tool.bodyLength + tool.holderLength);
    }
  }
  return tool.bodyLength + tool.holderLength;
}

function defineMachine() {
  var useTCP = true;
  if (false) { // note: setup your machine here
    var aAxis = createAxis({coordinate:0, table:true, axis:[1, 0, 0], range:[-120, 120], preference:1, tcp:useTCP});
    var cAxis = createAxis({coordinate:2, table:true, axis:[0, 0, 1], range:[-360, 360], preference:0, tcp:useTCP});
    machineConfiguration = new MachineConfiguration(aAxis, cAxis);

    setMachineConfiguration(machineConfiguration);
    if (receivedMachineConfiguration) {
      warning(localize("The provided CAM machine configuration is overwritten by the postprocessor."));
      receivedMachineConfiguration = false; // CAM provided machine configuration is overwritten
    }
  }

  if (!receivedMachineConfiguration) {
    // multiaxis settings
    if (machineConfiguration.isHeadConfiguration()) {
      machineConfiguration.setVirtualTooltip(false); // translate the pivot point to the virtual tool tip for nonTCP rotary heads
    }

    // retract / reconfigure
    var performRewinds = false; // set to true to enable the rewind/reconfigure logic
    if (performRewinds) {
      machineConfiguration.enableMachineRewinds(); // enables the retract/reconfigure logic
      safeRetractDistance = (unit == IN) ? 1 : 25; // additional distance to retract out of stock, can be overridden with a property
      safeRetractFeed = (unit == IN) ? 20 : 500; // retract feed rate
      safePlungeFeed = (unit == IN) ? 10 : 250; // plunge feed rate
      machineConfiguration.setSafeRetractDistance(safeRetractDistance);
      machineConfiguration.setSafeRetractFeedrate(safeRetractFeed);
      machineConfiguration.setSafePlungeFeedrate(safePlungeFeed);
      var stockExpansion = new Vector(toPreciseUnit(0.1, IN), toPreciseUnit(0.1, IN), toPreciseUnit(0.1, IN)); // expand stock XYZ values
      machineConfiguration.setRewindStockExpansion(stockExpansion);
    }

    // multi-axis feedrates
    if (machineConfiguration.isMultiAxisConfiguration()) {
      machineConfiguration.setMultiAxisFeedrate(
        useTCP ? FEED_FPM : FEED_INVERSE_TIME,
        9999.99, // maximum output value for inverse time feed rates
        INVERSE_MINUTES, // INVERSE_MINUTES/INVERSE_SECONDS or DPM_COMBINATION/DPM_STANDARD
        0.5, // tolerance to determine when the DPM feed has changed
        1.0 // ratio of rotary accuracy to linear accuracy for DPM calculations
      );
      setMachineConfiguration(machineConfiguration);
    }

    /* home positions */
    // machineConfiguration.setHomePositionX(toPreciseUnit(0, IN));
    // machineConfiguration.setHomePositionY(toPreciseUnit(0, IN));
    // machineConfiguration.setRetractPlane(toPreciseUnit(0, IN));
  }
}
// End of machine configuration logic ======================================================================

/**
 * function to reformat a string to 'title case'  
 * @param str the string to casify
 * @returns entitled string
 */
function toTitleCase(str)
   {
   return str.replace( /\w\S*/g, function(txt)
      {
      // /\w\S*/g    keep that format, astyle will put spaces in it
      return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
      });
   }
// ------- use astyle below thisline -----------------
/**
 * Translates a spindle RPM into a manual dial setting for specific router models.
 *
 * This function takes a target RPM and calculates the corresponding dial setting
 * (e.g., 1, 2.5, 6) for routers like Makita, Dewalt, and Router11. It uses linear
 * interpolation for speeds that fall between the fixed dial settings.
 *
 * It also validates the requested RPM against the selected router's capabilities.
 * If the RPM is out of range, it issues a warning to the user and clamps the
 * dial setting to the nearest valid value (minimum or maximum).
 *
 * The supported router types and their speed mappings are:
 * - **Dewalt 611**: [1: 16000, 2: 18200, 3: 20400, 4: 22600, 5: 24800, 6: 27000]
 * - **Router11**: [1: 10000, 2: 14000, 3: 18000, 4: 23000, 5: 27000, 6: 32000]
 * - **Makita RT0701 (Default)**: [1: 10000, 2: 12000, 3: 17000, 4: 22000, 5: 27000, 6: 30000]
 *
 * For probe operations, it returns a default dial setting of 1.
 *
 * @param {number} rpm The target spindle speed in revolutions per minute.
 * @param {string} op The name of the current operation, used for logging warning messages.
 * @returns {string|number} The calculated dial setting as a string with one decimal place (e.g., "2.5"),
 * or an integer for the minimum/maximum settings.
 */
function rpm2dial(rpm, op)
   {
   var wmsg = "";

   if (isProbeOperation())      
      return 1;

   var speeds;
   switch (properties.routerType) {
      case "Dewalt":
         speeds = [0, 16000, 18200, 20400, 22600, 24800, 27000];
         break;
      case "Router11":
         speeds = [0, 10000, 14000, 18000, 23000, 27000, 32000];
         break;
      case "Makita":
      default:
         // this is Makita R0701 and default for 'other'
         speeds = [0, 10000, 12000, 17000, 22000, 27000, 30000];
         break;
   }

   if (rpm < speeds[1])
      {
      wmsg = "WARNING " + rpm + " rpm is below minimum spindle RPM of " + speeds[1] + " rpm in the " + op + " operation.";
      warning(wmsg);
      writeComment(wmsg);
      return 1;
      }

   if (rpm > speeds[speeds.length - 1])
      {
      wmsg = "WARNING " + rpm + " rpm is above maximum spindle RPM of " + speeds[speeds.length - 1] + " rpm in the " + op + " operation.";
      warning(wmsg);
      writeComment(wmsg);
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

   error("Fatal Error calculating router speed dial.");
   return 0;
   }

/**
 * Checks various feed rates for a given operation against the GRBL minimum feed rate.
 *
 * This function retrieves the cutting, retract, entry, exit, ramp, and plunge feed rates
 * from the provided section object. It compares each of these against the `minimumFeedRate`
 * property (a GRBL controller limitation). If any feed rate is found to be below this
 * minimum, it generates a detailed warning message. This message is both displayed to the
 * user in the Fusion 360 post-process dialog and written as a comment in the output
 * G-code file for on-machine reference.
 *
 * @param {object} section The Fusion 360 section object for the current operation,
 *   which contains all toolpath parameters.
 * @param {string} op A descriptive name or identifier for the current operation,
 *   used within the warning message to help the user locate the issue.
 * @returns {void} This function does not return a value.
 */
function checkMinFeedrate(section, op)
   {
   var alertMsg = "";
   if (section.getParameter("operation:tool_feedCutting") < minimumFeedRate)
      alertMsg = "Cutting\n";
   if (section.getParameter("operation:tool_feedRetract") < minimumFeedRate)
      alertMsg = alertMsg + "Retract\n";
   if (section.getParameter("operation:tool_feedEntry") < minimumFeedRate)
      alertMsg = alertMsg + "Entry\n";
   if (section.getParameter("operation:tool_feedExit") < minimumFeedRate)
      alertMsg = alertMsg + "Exit\n";
   if (section.getParameter("operation:tool_feedRamp") < minimumFeedRate)
      alertMsg = alertMsg + "Ramp\n";
   if (section.getParameter("operation:tool_feedPlunge") < minimumFeedRate)
      alertMsg = alertMsg + "Plunge\n";

   if (alertMsg != "")
      {
      var fF = createFormat({decimals: 0, suffix: (unit == MM ? "mm" : "in" )});
      var fo = createVariable({}, fF);
      var wmsg = "WARNING " + "The following feedrates in " + op + "  are set below the minimum feedrate that GRBL supports.  The feedrate should be higher than " + fo.format(minimumFeedRate) + " per minute.\n\n" + alertMsg;
      warning(wmsg);
      writeComment(wmsg);
      }
   }

/**
 * write a block of gcode
 * counts lines if tapelines is set
 */
function writeBlock()
   {
   writeWords(arguments);
   if (SPL.tapelines)   SPL.linecnt++;   
   }

/**
 * Thanks to nyccnc.com
 * Thanks to the Autodesk Knowledge Network for help with this at
 * https://knowledge.autodesk.com/support/hsm/learn-explore/caas/sfdcarticles/sfdcarticles/How-to-use-Manual-NC-options-to-manually-add-code-with-Fusion-360-HSM-CAM.html!
*/
function onPassThrough(text)
   {
   var commands = String(text).split(",");
   for (text in commands)
      {
      writeBlock(commands[text]);
      }
   }

/**
 * 3. here you can set all the properties of your machine if you havent set up a machine config in CAM.  These are optional and only used to print in the header.
 * rather set up a real machine config
 */
function myMachineConfig()
   {
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

/** 
 * Remove special characters which could confuse GRBL : $, !, ~, ?, (, )
 * In order to make it simple, I replace everything which is not A-Z, 0-9, space, : , .
 * Finally put everything between () as this is the way GRBL & UGCS expect comments
*/   
function formatComment(text)
   {
   return ("(" + filterText(String(text), permittedCommentChars) + ")");
   }

/**
 * return seconds as a h:m:s string
 * @param secs seconds of time
 */
function getTimeText(secs)
   {
   var machineTimeInSeconds = secs;
   var machineTimeHours = Math.floor(machineTimeInSeconds / 3600);
   machineTimeInSeconds = machineTimeInSeconds % 3600;               // remove the hours
   var machineTimeMinutes = Math.floor(machineTimeInSeconds / 60);
   var machineTimeSeconds = Math.floor(machineTimeInSeconds % 60);   // remove the minutes
   var machineTimeText = subst(localize("%1h:%2m:%3s"), machineTimeHours, machineTimeMinutes, machineTimeSeconds);
   return machineTimeText;
   }

/**
 * returns the time as 'machining time 00h00m00s'
 */
function getMachineTime(sec)
   {
   var machineTimeInSeconds = sec.getCycleTime();
   var machineTimeText = "  Machining time : ";   
   machineTimeText += getTimeText(machineTimeInSeconds);
   return machineTimeText;
   }   

/**
 * Writes a formatted G-code comment to the output file, automatically handling line wrapping.
 *
 * This function takes a string and formats it as a valid GRBL comment (e.g., "(My Comment)").
 * If the input text exceeds 70 characters, it intelligently splits the string at word
 * boundaries to create multiple comment lines, each under the length limit. This prevents
 * issues with G-code controllers that may not handle very long single-line comments.
 *
 * @param {string} text The comment string to write. Can be a single line or a long string that needs wrapping.
 * @returns {void}
 */
function writeComment(text)
   {
   // v20 - split the line so no comment is longer than 70 chars
   if (text)
   if (text.length > 70)
      {
      //text = String(text).replace( /[^a-zA-Z\d:=,.]+/g, " "); // remove illegal chars
      text = filterText(text.trim(), permittedCommentChars);
      var bits = text.split(" "); // get all the words
      var out = '';
      for (i = 0; i < bits.length; i++)
         {
         out += bits[i] + " "; // additional space after first line
         if (out.length > 60)           // a long word on the end can take us to 80 chars!
            {
            writeln(formatComment( out.trim() ) );
            out = "";
            }
         }
      if (out.length > 0)
         writeln(formatComment( out.trim() ) );
      }
   else
      writeln(formatComment(text));
   }

/**
 * Writes the header information at the beginning of a G-code file.
 *
 * This function generates a comprehensive header containing metadata about the job,
 * the post-processor, and the machine setup. It includes:
 * - Product and post-processor version information.
 * - Unit system (mm or inch).
 * - Warnings for unsupported features (e.g., multiple tools in a single file).
 * - A detailed list of all operations (or a subset for multi-file jobs),
 *   including tool details, spindle speeds, work coordinates, and estimated machining time.
 * - For multi-file jobs, it lists all generated filenames in the header of the first file.
 * - It concludes by setting up the initial G-code modal states (G90, G94, G17, G21/G20).
 *
 * @param {number} secID The starting section (operation) ID. For the first file, this is 0.
 *   For subsequent files in a multi-file job, this will be the ID of the first
 *   operation in that new file.
 * @returns {void}
 */   
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
   writeComment("G-Code optimized for " + properties.machineControl + " controller");
   writeComment(description);
   cpsname = FileSystem.getFilename(getConfigurationPath());
   writeComment("Post-Processor : " + cpsname + " " + obversion );
   //writeComment("Post processor documentation: " + properties.postProcessorDocs );
   var unitstr = (unit == MM) ? 'mm' : 'inch';
   writeComment("Units = " + unitstr );
   if (isJet())
      {
      writeComment("Laser UseZ = " + properties.UseZ);
      writeComment("Laser UsePierce = " + properties.UsePierce);
      }
   if (allowedCircularPlanes == 1)
      {
      writeln("");   
      writeComment("Arcs are limited to the XY plane: if you want vertical arcs then edit allowedCircularPlanes in the CPS file");
      }
   else   
      {
      writeln("");   
      writeComment("Arcs can occur on XY,YZ,ZX planes: CONTROL may not display them correctly but they will cut correctly");
      }

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
   // output stock size
   var xl = getGlobalParameter('stock-lower-x');
   var yl = getGlobalParameter('stock-lower-y');
   var xu = getGlobalParameter('stock-upper-x');
   var yu = getGlobalParameter('stock-upper-y');
   var zl = getGlobalParameter('stock-lower-z');
   var zu = getGlobalParameter('stock-upper-z');
   var xs = xu - xl;
   var ys = yu - yl;
   var zs = zu - zl;
   writeComment("Stock : XxYxZ : " + xs.toPrecision(2) + "x" + ys.toPrecision(2)  + "x" + zs.toPrecision(2) )  
   writeln("");

   numberOfSections = getNumberOfSections();
   if (properties.generateMultiple && filesToGenerate > 1)
      {
      if (properties.splitLines > 0)
         {
         writeComment("Since we are splitting on line count we don't know how many files will be written.");   
         writeComment("There will be at least " + filesToGenerate + " files, from the number of tools.");
         writeComment("Files will be named like programName.01ofMany.nc")
         writeComment(numberOfSections + " Operation" + ((numberOfSections == 1) ? "" : "s") );
         }   
      else
         {
         writeComment(numberOfSections + " Operation" + ((numberOfSections == 1) ? "" : "s") + " in " + filesToGenerate + " files.");
         writeComment("File List:");
         //writeComment("  " +  FileSystem.getFilename(getOutputPath()));
         for (var i = 0; i < filesToGenerate; ++i)
            {
            filename = makeFileName(i + 1);
            writeComment("  " + filename);
            }
         writeln("");
         writeComment("This is file: " + sequenceNumber + " of " + filesToGenerate);
         }
      writeln("");
      writeComment("This file contains the following operations: ");
      }
   else
      {
      writeComment(numberOfSections + " Operation" + ((numberOfSections == 1) ? "" : "s") + " :");
      }
   var totalSeconds = 0;
   for (var i = secID; i < numberOfSections; ++i)
      {
      var section = getSection(i);
      var tool = section.getTool();
      var rpm = section.getMaximumSpindleSpeed();

      setOperationType(tool);

      if (section.hasParameter("operation-comment"))
         {
         var op = section.getParameter("operation-comment");
         writeComment((i + 1) + " : " + op);
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
      if (OB.isLaser || OB.isPlasma)
         {
         writeComment("  Tool #" + tool.number + ": " + toTitleCase(getToolTypeName(tool.type)) + " Diam = " + xyzFormat.format(tool.jetDiameter) + unitstr);
         if (OB.isPlasma)
            writeComment("How to use this post for plasma https://github.com/OpenBuilds/OpenBuilds-Fusion360-Postprocessor/blob/master/README-plasma.md");
         if (OB.isLaser)   
            switch (section.getJetMode() )
               {
               case JET_MODE_THROUGH:
                  OB.power = calcPower(properties.PowerThrough);
                  writeComment("  LASER THROUGH CUTTING " + properties.PowerThrough + "percent = S" + OB.power);
                  break;
               case JET_MODE_ETCHING:
                  OB.power = calcPower(properties.PowerEtch);
                  writeComment("  LASER ETCH CUTTING " + properties.PowerEtch + "percent = S" + OB.power);
                  break;
               case JET_MODE_VAPORIZE:
                  OB.power = calcPower(properties.PowerVaporise);
                  writeComment("  LASER VAPORIZE CUTTING " + properties.PowerVaporise + "percent = S" + OB.power);
                  break;
               default:
                  error(localize("Unsupported cutting mode."));
                  return;
               }
         }
      else
         {
         if (getToolTypeName( tool.type) == 'probe')
            writeComment("  Tool #" + tool.number + ": " + toTitleCase(getToolTypeName(tool.type)) + " Diam = " + xyzFormat.format(tool.diameter) + unitstr + ", Len = " + tool.fluteLength.toFixed(2) + unitstr);
         else
            {
            writeComment("  Tool #" + tool.number + ": " + toTitleCase(getToolTypeName(tool.type)) + " " + tool.numberOfFlutes + " Flutes, Diam = " + xyzFormat.format(tool.diameter) + unitstr + ", Len = " + tool.fluteLength.toFixed(2) + unitstr);
            if (isProbeOperation()) 
               {
               writeComment('Probing, no dial to set')   ;
               }
            else
               if (properties.routerType != "other")
                  {
                  writeComment("  Spindle : RPM = " + round(rpm, 0) + ", set " + properties.routerType + " dial to " + rpm2dial(rpm, op));
                  }
               else
                  {
                  writeComment("  Spindle : RPM = " + round(rpm, 0) + " " + properties.routerType);
                  }
            }      
         }
      if (section.strategy != 'probe')
         checkMinFeedrate(section, op);
      machineTimeText = getMachineTime(section);
      totalSeconds += section.getCycleTime();
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
   machineTimeText = "Total Machining time : " + getTimeText(totalSeconds);
   writeComment(machineTimeText);
   writeln("");

   // Restore the OB state to be correct for the current tool. The loop above
   // will have left the state set for the *last* tool in the entire job.
   setOperationType(getSection(secID).getTool());

   if (OB.isLaser || OB.isPlasma)
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
   if (debugMode)
      {
         var msg = "debugMode is true";
      writeComment(msg);
      warning(msg);
      writeln("");
      }
   }

/**
 * Initializes the post-processing job, performs critical validation, and writes the file header.
 *
 * This is the main entry point function called by the CAM system when the post-processor
 * is executed. It orchestrates the initial setup by:
 * 1.  Activating the machine configuration, either from the CAM setup or a hardcoded definition.
 * 2.  Initializing state for features like splitting G-code files by line count.
 * 3.  Performing several crucial validation checks:
 *     -   Ensuring radius compensation is not used, as it's unsupported by GRBL (fatal error).
 *     -   Detecting if the same tool number is assigned to tools with different geometries (fatal error).
 *     -   Warning the user if multiple tools are present but the multi-file output option is disabled.
 * 4.  Calculating the number of files to be generated based on tool changes.
 * 5.  Calling `writeHeader()` to output the initial comments, settings, and operation list.
 * 6.  Configuring initial states for Z-axis motion, especially for plasma and laser operations.
 *
 * @returns {void} This function does not return a value.
 */
function onOpen()
   {
   receivedMachineConfiguration = machineConfiguration.isReceived();
   if (typeof defineMachine == "function") 
      {
      defineMachine(); // hardcoded machine configuration
      }
   activateMachine(); // enable the machine optimizations and settings
    
   // 3. moved to top of file
   //myMachineConfig();
   numberOfSections = getNumberOfSections();
   if (properties.splitLines > 0)   
      {
      SPL.tapelines = properties.splitLines;
      }
   
   if (debugMode) writeComment("onOpen");
   // Number of checks capturing fatal errors
   // 2. is RadiusCompensation not set incorrectly ?
   onRadiusCompensation();

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
               error( subst(
                         localize("Using the same tool number for different cutter geometry for operation '%1' and '%2'."),
                         sectioni.hasParameter("operation-comment") ? sectioni.getParameter("operation-comment") : ("#" + (i + 1)),
                         sectionj.hasParameter("operation-comment") ? sectionj.getParameter("operation-comment") : ("#" + (j + 1))
                      ) );
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
      var mte = "WARNING " + "Multiple tools found.  This post does not support tool changes.  You should repost and select True for Multiple Files in the post properties.";
      warning(mte);
      writeComment(mte);
      }

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

/**
 * Calculates the raw PWM value for a given power percentage for the laser.
 *
 * This function translates a power level, specified as a percentage (0-100),
 * into a raw value suitable for the 'S' word in G-code, which controls
 * spindle speed or laser/plasma power. It linearly maps the percentage to a
 * configurable PWM range.
 *
 * The default range is [0, 1000], corresponding to GRBL's default spindle
 * speed settings. These values (PWMMin, PWMMax) can be modified directly
 * within the function if a different range is required.
 *
 * @param {number} perc The desired power level as a percentage (0-100).
 * @returns {number} The calculated raw PWM value (e.g., 50% returns 500).
 */
function calcPower(perc)
   {
   var PWMMin = 0;  // make it easy for users to change this
   var PWMMax = 1000;
   var v = PWMMin + (PWMMax - PWMMin) * perc / 100.0;
   return round(v,0);
   }

/**
 * Moves the tool to the initial XY position for the current operation.
 *
 * This function generates a rapid G0 move to the starting XY coordinates of the
 * current section. It also includes an optional, user-configurable feature to
 * perform a tool height check for milling operations.
 *
 * The tool height check, if enabled via post properties (`checkZ`), will:
 * 1. Move the tool at a specified feed rate (`checkFeed`) to the `Heights.clearance`.
 * 2. Issue a program pause (M0) to allow the operator to verify the tool length.
 *
 * This check is only performed for the first section of a new file and is
 * automatically disabled for laser and plasma operations.
 *
 * @param {boolean} checkit If true, enables the tool height check routine,
 *   provided the corresponding post properties are also enabled.
 * @returns {void}
 */
function gotoInitial(checkit)
   {
   if (debugMode) writeComment("gotoInitial start");
   var sectionId = getCurrentSectionId();       // what is the number of this operation (starts from 0)
   var section = getSection(sectionId);         // what is the section-object for this operation
   var maxfeedrate = section.getMaximumFeedrate();
   var f = "";
   var z;
   
   // Rapid move to initial position, first XY, then Z, and do tool height check if needed
   forceAny();
   var initialPosition = getFramePosition(currentSection.getInitialPosition());
   if (OB.isLaser || OB.isPlasma)
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
         // do a Peter Stanton style Z seek and stop for a height check - https://youtu.be/WMsO24IqRKU?t=1059
         z = zOutput.format(Heights.clearance);
         f = feedOutput.format(toPreciseUnit(properties.checkFeed, MM));
         writeln("(Tool Height check https://youtu.be/WMsO24IqRKU?t=1059)");
         writeBlock(gMotionModal.format(1), z, f );
         writeBlock(mOutput.format(0));
         }
   if (debugMode) writeComment("gotoInitial end");
   }

/**
 * Generates a G53 G0 command to retract the Z-axis to a safe, absolute machine coordinate.
 *
 * This function creates a critical safety move. It uses a non-modal `G53` command,
 * which temporarily overrides the current work coordinate system (like G54) and
 * moves the Z-axis relative to the machine's home position. This ensures a
 * predictable and safe retract height, regardless of the active work offset.
 *
 * The target Z position is read from the `properties.machineHomeZ` post-processor
 * property, which is always interpreted in millimeters.
 *
 * A comment is also written to the G-code file, warning the operator that this
 * move relies on the machine having been properly homed.
 *
 * The function also manages modal states by resetting the Z-axis output and the
 * motion modal group to ensure the next move command is explicitly written.
 *
 * @returns {void} This function does not return a value.
 */
function writeZretract()
   {
   zOutput.reset();
   gMotionModal.reset();
   //gFormat.reset();
   //writeln("(This relies on homing, see https://openbuilds.com/search/127200199/?q=G53+fusion )");
   writeln("(This relies on homing, see https://github.com/OpenBuilds/OpenBuilds-Fusion360-Postprocessor/wiki/FAQ)");
   writeBlock(gFormat.format(53), gMotionModal.format(0), zOutput.format(toPreciseUnit( properties.machineHomeZ, MM)));  // Retract spindle to Machine Z Home
   gMotionModal.reset();
   zOutput.reset();
   }

/**
 * Main event handler called at the beginning of each CAM operation (section).
 *
 * This function orchestrates the setup for each distinct operation in the CAM file.
 * It is responsible for a wide range of tasks, including:
 *
 * - **File Management**: Detects if a new file needs to be created due to a tool
 *   change or if the line count limit has been exceeded. It manages the process
 *   of closing the previous file and opening a new one with a proper header and
 *   resume sequence.
 * - **Operation Setup**: Determines the type of operation (milling, laser, plasma)
 *   and configures the post-processor's internal state accordingly.
 * - **Validation**: Performs critical checks, such as ensuring unsupported radius
 *   compensation is not used and validating pierce/cut heights for plasma/laser tools.
 * - **WCS Handling**: Manages the Work Coordinate System (e.g., G54, G55), issuing
 *   the correct command and performing safety retracts if the WCS changes between
 *   sections.
 * - **Tool Initialization**:
 *   - For milling, it handles the initial Z-retract, moves to the start position,
 *     and starts the spindle with the correct speed and delay.
 *   - For laser/plasma, it sets power levels and cutting modes and handles initial
 *     Z moves if enabled.
 * - **State Reset**: Resets modal G-code states to ensure the new section starts
 *   cleanly without unexpected behavior from the previous section.
 *
 * This function contains several local helper functions (prefixed with `L_`) to
 * manage its complexity.
 *
 * @returns {void} This function does not return a value. It modifies the G-code
 *   output and internal state directly.
 */
function onSection()
   {
   var nmbrOfSections = getNumberOfSections();  // how many operations are there in total
   var sectionId = getCurrentSectionId();       // what is the number of this operation (starts from 0)
   var section = getSection(sectionId);         // what is the section-object for this operation
   var tool = section.getTool();
   var maxfeedrate = section.getMaximumFeedrate();
   var amProbing = false;
   OB.haveRapid = false; // drilling sections will have rapids even when other ops do not, and so do probe routines

   setOperationType(tool); // sets isLaser etc
   onRadiusCompensation(); // must check every section

   if (OB.isPlasma || OB.isLaser)
      {
      //DAF Mar2024 - pierceclearance is not the pierceheight, that is defined for the tool
      var whoami = OB.isLaser ? 'laser' : 'plasma';
      if (properties.plasma_pierceHeightoverride)
         plasma.pierceHeight = parseFloat(properties.plasma_pierceHeightValue);
      else
         plasma.pierceHeight = tool.pierceHeight; // NOT pierceClearance!
      // now we can do a valid height check
      if (plasma.cutHeight > plasma.pierceHeight)
         {
         writeComment(whoami + ".cutHeight " + plasma.cutHeight)   ;
         writeComment(whoami + ".pierceHeight " + plasma.pierceHeight);
         error("CUT HEIGHT MUST BE BELOW PLASMA TOOL PIERCE HEIGHT (tool setting)");
         }
      if ( (plasma.cutHeight == 0) || (tool.cutHeight == 0) )
         if ((Heights.top <= 0) && properties.plasma_usetouchoff)
            error("TOPHEIGHT MUST BE GREATER THAN 0 (heights tab) when tool has no cutHeight");
      writeComment(whoami + " pierce height " + round(plasma.pierceHeight,3));
      writeComment(whoami + " topHeight " + round(Heights.top,3));
      writeComment(whoami + " cutHeight " + round(plasma.cutHeight,3));
      writeComment(whoami + " pierceTime " + round(plasma.pierceTime,3));
      }
   if (OB.isLaser || OB.isPlasma)
      {
      // fake the radius larger else the arcs are too small before being linearized since kerfwidth is very small compared to normal tools
      if (tool.kerfWidth < toPreciseUnit(2,MM))
         toolRadius = tool.kerfWidth * 3;
      allowHelicalMoves = false; // laser/plasma not doing this, ever
      }
   else
      {
      toolRadius = tool.diameter / 2.0;
      }

   //TODO : plasma check that top height mode is from stock top and the value is positive
   //(onParameter =operation:topHeight mode= from stock top)
   //(onParameter =operation:topHeight value= 0.8)

   var splitHere = !isFirstSection() && properties.generateMultiple && (tool.number != getPreviousSection().getTool().number);
   // to split on linecount, we need to force it here
   if (SPL.forceSplit)
      {
      splitHere = true;  // will open a new file
      writeComment('Starting new file due to line count');
      filesToGenerate++;
      }

   if (splitHere)
      {
      sequenceNumber++;
      var path = makeFileName(sequenceNumber);
      if (SPL.forceSplit)
         writeComment("Next file " + path);  

      if (isRedirecting())
         {
         if (debugMode) writeComment("onSection: closing redirection");
         onClose();
         closeRedirection();
         }
      redirectToFile(path);
      forceAll();
      writeHeader(getCurrentSectionId());
      isNewfile = true;  // trigger a spindleondelay
      }
   if (SPL.forceSplit)    
      { 
      forceAll();
      writeComment("Continuing operation, run previous file, " + String(sequenceNumber - 1) + ", first");
      SPL.forceSplit = false;
      gMotionModal.reset();
      writeZretract();
      }

   if (debugMode) writeComment("onSection " + sectionId);
   writeln(""); // put these here so they go in the new file
   //writeComment("Section : " + (sectionId + 1) + " haveRapid " + haveRapid);

   // Insert a small comment section to identify the related G-Code in a large multi-operations file
   var comment = "Operation " + (sectionId + 1) + " of " + nmbrOfSections;
   if (hasParameter("operation-comment"))
      {
      comment = comment + " : " + getParameter("operation-comment");
      }
   writeComment(comment);
   if (debugMode)
      writeComment("Heights.retract = " + round(Heights.retract, 3));

   // retract again if not first section and WCS changed
   if (!isFirstSection() && (currentworkOffset !=  (53 + section.workOffset)) )
      {
      writeZretract();
      }
      
   if ((section.workOffset < 1) || (section.workOffset > 6))
      {
      var mcsmsg = "WARNING " + "Invalid Work Coordinate System. Select WCS 1..6 in SETUP:PostProcess tab. Selecting default WCS1/G54";
      warning(mcsmsg);
      writeComment(mcsmsg);
      //section.workOffset = 1;  // If no WCS is set (or out of range), then default to WCS1 / G54 : swarfer: this appears to be readonly
      writeBlock(gWCSOutput.format(54));  // output what we want, G54
      currentworkOffset = 54;
      }
   else
      {
      // Write the WCS, ie. G54 or higher.. default to WCS1 / G54 if no or invalid WCS
      if ( (53+section.workOffset) != currentworkOffset)
         {
         currentworkOffset = 53 + section.workOffset;
         writeBlock(gWCSOutput.format(currentworkOffset));  // use the selected WCS
         }
      }
   writeBlock(gAbsIncModal.format(90));  // Set to absolute coordinates

   // If the machine has coolant, write M8/M7 or M9 on spindle control line
   // if probing ensure coolant is off
   if (properties.hasCoolant)
      {
      if (OB.isLaser || OB.isPlasma)
         {
         clnt = setCoolant(1); // always turn it on since plasma tool has no coolant option in fusion
         writeComment('laser coolant ' + clnt);
         }
      else
         clnt = setCoolant(tool.coolant); // use tool setting
      }

   OB.cutmode = -1;
   //writeComment("isMilling=" + isMilling() + "  isjet=" +isJet() + "  islaser=" + isLaser);
   switch (tool.type)
      {
      case TOOL_WATER_JET:
         writeComment("Waterjet cutting with GRBL.");
         OB.power = calcPower(100); // always 100%
         OB.cutmode = 3;
         OB.isLaser = false;
         OB.isPlasma = true;
         //writeBlock(mOutput.format(cutmode), sOutput.format(OB.power));
         break;
      case TOOL_LASER_CUTTER:
         //writeComment("Laser cutting with GRBL.");
         OB.isLaser = true;
         OB.isPlasma = false;
         var pwas = OB.power;
         switch (currentSection.getJetMode() )
            {
            case JET_MODE_THROUGH:
               OB.power = calcPower(properties.PowerThrough);
               writeComment("LASER THROUGH CUTTING " + properties.PowerThrough + "percent = S" + OB.power);
               break;
            case JET_MODE_ETCHING:
               OB.power = calcPower(properties.PowerEtch);
               writeComment("LASER ETCH CUTTING " + properties.PowerEtch + "percent = S" + OB.power);
               break;
            case JET_MODE_VAPORIZE:
               OB.power = calcPower(properties.PowerVaporise);
               writeComment("LASER VAPORIZE CUTTING " + properties.PowerVaporise + "percent = S" + OB.power);
               break;
            default:
               error(localize("Unsupported cutting mode."));
               return;
            }
         // figure cutmode, M3 or M4
         if ((OB.cuttingMode == 'etch') || (OB.cuttingMode == 'vaporize'))
            OB.cutmode = 4; // always M4 mode unless cutting
         else
            OB.cutmode = 3;
         if (pwas != OB.power)
            {
            sOutput.reset();
            //if (isFirstSection())
            if (OB.cutmode == 3)
               writeBlock(mOutput.format(OB.cutmode), sOutput.format(0), '; flash preventer'); // else you get a flash before the first g0 move
            else
               if (OB.cuttingMode != 'cut')
                  writeBlock(mOutput.format(OB.cutmode), sOutput.format(OB.power), clnt, '; section power');
            }
         break;
      case TOOL_PLASMA_CUTTER:
         writeComment("Plasma cutting with GRBL.");
         if (properties.plasma_usetouchoff)
            writeComment("Using torch height probe and pierce delay.");
         OB.power = calcPower(100); // always 100%
         OB.cutmode = 3;
         OB.isLaser = false;
         OB.isPlasma = true;
         //writeBlock(mOutput.format(cutmode), sOutput.format(OB.power));
         break;
      case TOOL_PROBE:
         amProbing = true;
         writeComment('Tool is a 3D Probe');
         clnt = setCoolant(0);
         writeBlock(clnt);
         clnt = '';
         break;
      default:
         //writeComment("tool.type = " + tool.type); // all milling tools
         OB.isPlasma = OB.isLaser = false;
         break;
      }

   if ( !OB.isLaser && !OB.isPlasma )
      {
      // To be safe (after jogging to whatever position), move the spindle up to a safe home position before going to the initial position
      // At end of a section, spindle is retracted to clearance height, so it is only needed on the first section
      // it is done with G53 - machine coordinates, so I put it in front of anything else
      if (isFirstSection())
         {
         writeZretract();
         }
      else
         if (properties.generateMultiple && (tool.number != getPreviousSection().getTool().number))
            writeZretract();
      // to enable tool code output, uncomment the toolformat line and 1 (one) of the writeblock lines according to your needs   
      //var toolFormat = createFormat({ decimals: 0 });         
      //writeBlock("T" + toolFormat.format(tool.number), mOutput.format(6));
      //writeBlock("T" + toolFormat.format(tool.number));
      gotoInitial(true);

      // folks might want coolant control here
      // Insert the Spindle start command
      if (clnt)
         {
         // force S and M words if coolant command exists
         sOutput.reset();
         mOutput.reset();
         }
      if (amProbing)   
         {
         m = mOutput.format(5);   // stop the spindle
         writeBlock(m);
         m = '';  // prevent spindle delay
         }
      else
         if (tool.clockwise)
            {
            var rpmChanged = false;
            if ( (sOutput.getCurrent() != Infinity) && rpmFormat.areDifferent(tool.spindleRPM, sOutput.getCurrent()) )
               {
               s = sOutput.format(tool.spindleRPM);
               rpmChanged = true;
               mOutput.reset();
               }
            else
               s = sOutput.format(tool.spindleRPM);
            //if (s)
            //   {
            //   rpmChanged = !mFormat.areDifferent(3, mOutput.getCurrent() );
            //   mOutput.reset();  // always output M3 if speed changes - helps with resume
            //   }
            m = mOutput.format(3);
            writeBlock(m, s, clnt);
            if (rpmChanged) // means a speed change, spindle was already on, delay half the time
               onDwell(properties.spindleOnOffDelay / 2);
            }
         else
            if (properties.spindleTwoDirections)
               {
               s = sOutput.format(tool.spindleRPM);
               m = mOutput.format(4);
               writeBlock(s, m, clnt);
               }
            else
               {
               warning("ERROR - Counter-clockwise Spindle Operation found, but your spindle does not support this");
               error("Fatal Error in Operation " + (sectionId + 1) + ": Counter-clockwise Spindle Operation found, but your spindle does not support this");
               return;
               }
      // spindle on delay if needed
      if (m && (isFirstSection() || isNewfile))
         onDwell(properties.spindleOnOffDelay);
      }
   else
      {
         // laser or plasma
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
      warning("ERROR : Tool-Rotation detected - this GRBL post only supports 3 Axis");
      error("Fatal Error in Operation " + (sectionId + 1) + ": Tool-Rotation detected but GRBL only supports 3 Axis");
      }
   setRotation(remaining);

   forceAny();

   if (OB.isLaser && properties.UseZ)
      writeBlock(gMotionModal.format(0), zOutput.format(0));
   isNewfile = false;
   //writeComment("onSection end");
   }

/**
 * Generates a G-code dwell command (G4).
 *
 * This function creates a program pause for a specified duration. It validates
 * the input duration to be within a reasonable range (0.0 to 999 seconds).
 *
 * If the requested duration is outside this range, it defaults to a special
 * value of 3.14 seconds. This prevents errors from invalid G-code while
 * allowing the post-processing to complete, signaling a minor oversight
 * in the input parameters without halting the job.
 *
 * @param {number} seconds The duration of the dwell in seconds.
 * @returns {void}
 */
function onDwell(seconds)
   {
   if ((seconds < 0.0) || (seconds > 999))
      seconds = 3.14;
   writeBlock(gFormat.format(4), "P" + secFormat.format(seconds));
   }

function onSpindleSpeed(spindleSpeed)
   {
   if ( rpmFormat.areDifferent(spindleSpeed, sOutput.getCurrent()) )
      {
      var mv = mOutput.getCurrent();   
      mOutput.reset();  // always output the M word, makes it easier to read
      writeBlock(mOutput.format(mv), sOutput.format(spindleSpeed), ' ; ' , OB.movestr);
      gMotionModal.reset(); // force a G word after a spindle speed change to keep CONTROL happy
      }
   }

/// store the movement type for comments
function onMovement(movement) 
   {
   var jet = tool.isJetTool && tool.isJetTool();
   var movestr = getMovementStringId(movement, jet);
   if (movestr != OB.movestr)
      {
      OB.movestrP = OB.movestr;   // save old movestr
      OB.movestr = movestr;   // save new movestr
      }   
   }

function onRadiusCompensation()
   {
   var radComp = getRadiusCompensation();
   if (radComp != RADIUS_COMPENSATION_OFF)
      {
      var sectionId = getCurrentSectionId();
      warning("ERROR : RadiusCompensation is not supported in GRBL - Change RadiusCompensation in CAD/CAM software to Off/Center/Computer");
      error("Fatal Error in Operation " + (sectionId + 1) + ": RadiusCompensation is found in CAD file but is not supported in GRBL");
      return;
      }
   }

/**
   Handles rapid moves (G0).
   This function is called for every rapid traversal move in the toolpath. It generates
   the appropriate G0 command and handles specific logic for different operation types.
   For milling, it's a standard G0 XYZ move. For plasma, it manages the Z height
   to avoid crashing into the material before a pierce cycle. It also checks if the
   g-code file needs to be split due to line count limits.

   @param {number} _x The target X-coordinate for the rapid move.
   @param {number} _y The target Y-coordinate for the rapid move.
   @param {number} _z The target Z-coordinate for the rapid move.
*/
function onRapid(_x, _y, _z)
   {
   if (debugMode) writeComment("onRapid " + OB.haveRapid);      
   OB.haveRapid = true;
   gMotionModal.reset(); // want G word for rapids
   //if (debugMode) writeComment("onRapid");
   if (OB.isMill)
      {
      var x = xOutput.format(_x);
      var y = yOutput.format(_y);
      var z = zOutput.format(_z);

      if (x || y || z)
         {
         linmode = 0;
         //writeBlock(gMotionModal.format(0), x, y, z, " ; Rapid move " , OB.movestr);
         writeBlock(gMotionModal.format(0), x, y, z);
         feedOutput.reset();
         }
      }
   else
      {
      var x = xOutput.format(_x);
      var y = yOutput.format(_y);
      var z = "";
      if (OB.isPlasma && properties.UseZ)  // laser does not move Z during cuts
         {
         z =  (_z < plasma.pierceHeight) ? zOutput.format(plasma.pierceHeight) :  zOutput.format(_z) ;
         //writeComment("1408 z = " + z);
         //z = zOutput.format(_z);
         }
      // if (OB.isPlasma && properties.UseZ && (xyzFormat.format(_z) == xyzFormat.format(plasma.pierceHeight)) )
      //    {
      //    if (debugMode) writeComment("onRapid skipping Z motion");
      //    if (x || y)
      //       writeBlock(gMotionModal.format(0), x, y);
      //    zOutput.reset();   // force it on next command
      //    }
      // else
      if (x || y || z)
         {
         linmode = 0;
         writeBlock(gMotionModal.format(0), x, y, z);
         }
      }
   // split AFTER rapid move since it is most likely to be a safe spot to resume from      
   if (handleFileSplitting(_x, _y, _z, 0, true)) 
      return;
   }

/**
   Handles linear moves (G1).
   This function is called for every linear move in the toolpath. It determines whether
   the move should be a rapid (G0) or a feed move (G1) based on the operation type
   (milling vs. laser/plasma) and the current state (e.g., power on/off, Z height).
   It also handles splitting the G-code into multiple files if the line count limit is reached.

   @param {number} _x The target X-coordinate for the linear move.
   @param {number} _y The target Y-coordinate for the linear move.
   @param {number} _z The target Z-coordinate for the linear move.
   @param {number} feed The feed rate for the move.
*/
function onLinear(_x, _y, _z, feed)
   {
   //writeComment("onLinear " + OB.haveRapid + " ismill " + OB.isMill);
   if (OB.powerOn || OB.haveRapid)   // do not reset if power is off - for laser G0 moves
      {
      xOutput.reset();
      yOutput.reset(); // always output x and y else arcs go mad
      }
   var x = xOutput.format(_x);
   var y = yOutput.format(_y);
   var f = feedOutput.format(feed);
   linmove = 1;          // have to have a default!

   // Determine if the upcoming move is a rapid move (G0)
   var isRapidMove = false;
   if (OB.isMill)
      {
      // For milling, a move to or above Heights.retract is a rapid move (if not in a rapid cycle)
      //if (debugMode) 
      if (!OB.haveRapid && nearGE(_z , Heights.retract) )
         {
         isRapidMove = true;
         //if (debugMode) writeComment('1728 israpid');
         }
      else   
         // a direct move is rapid, used in adaptive clearing   
         if (OB.movestr == 'direct')  
            {
            //if (debugMode) writeComment('1733 direct to rapid');
            var start = getCurrentPosition();
            var end = new Vector(_x, _y, _z);
            end.setZ(start.z);    // ignore Z motion
            // only if a longer horizontal move than toolRadius
            if (Vector.diff(start, end).length > toolRadius)
               {
               isRapidMove = true; 
               if (debugMode) writeComment('1742 vectordiff rapid');
               }
            }
         else
            if (Feeds.cutting != Feeds.entry) // forces presense of leadin moves which we need
               if ((OB.movestrP == 'lead out') && (OB.movestr == 'cutting'))
                  {
                  isRapidMove = true;
                  if (debugMode) writeComment('1750 leadout to rapid');
                  }
      }
   else
      {
      // For laser/plasma, any move with the power off is a rapid move
      isRapidMove = !OB.powerOn;
      }
   linmove  = isRapidMove ? 0 : 1;
   if (isRapidMove)
      {
      gMotionModal.reset(); // want G word for rapids
      feedOutput.reset();
      f = "";
      }

   if (OB.isMill)
      {
      var currentZ = zOutput.getCurrent();
      var z = zOutput.format(_z);
      if (x || y || z)
         {
         // if at retract and going below top then rapid to top+0.25mm to save time   
         if (nearGE(currentZ, Heights.retract))
             if (_z < Heights.top)
                {
                // approach surface rapidly to just above top height  
                //writeBlock(gMotionModal.format(0), zOutput.format(Heights.top + toPreciseUnit(0.25,MM)), " ; approach");
                writeBlock(gMotionModal.format(0), zOutput.format(Heights.top + toPreciseUnit(0.25,MM)) );
                feedOutput.reset();
                f = feedOutput.format(feed); // force feed output after approach move
                }
         //writeBlock(gMotionModal.format(linmove), x, y, z, f, " ; ", OB.movestr);
         writeBlock(gMotionModal.format(linmove), x, y, z, f);
         }
      else
         if (f)
            {
            if (getNextRecord().isMotion())
               feedOutput.reset(); // force feed on next line
            else
               writeBlock(gMotionModal.format(1), f);
            }
      }
   else
      {
      // laser, plasma
      if (x || y)
         {
         // never going to cut lower than cutheight
         var z = properties.UseZ ? (_z <= plasma.pierceHeight) ? zOutput.format(OB.powerOn ? plasma.cutHeight : plasma.pierceHeight) :  zOutput.format(_z) : "";
         //if (OB.isLaser && !properties.UsePierce)
          //  z = 'z0';
         if (debugMode && z != "")            writeComment("onlinear z = " + z);
         var s = sOutput.format(OB.power);
         // For laser/plasma, G0 is used for non-cutting moves (power off)
         // and G1 is used for cutting moves (power on). The OB.haveRapid
         // flag is not needed here as the logic is the same regardless.
         if (isRapidMove)
            {
            f = '';  // do not output feed for rapid moves
            feedOutput.reset();  // force it on next G1 move
            }
         writeBlock(gMotionModal.format(linmove), x, y, z, f, s);
            }
         }
   if (handleFileSplitting(_x, _y, _z, feed, isRapidMove)) 
      return;
      }

/**
 * GRBL cannot do 5D and nor can this post
 */
function onRapid5D(_x, _y, _z, _a, _b, _c)
   {
   warning("ERROR : Tool-Rotation detected - this GRBL post only supports 3 Axis");
   error("Tool-Rotation detected but this GRBL post only supports 3 Axis");
   }

/**
 * GRBL cannot do 5D and nor can this post
 */
function onLinear5D(_x, _y, _z, _a, _b, _c, feed)
   {
   warning("ERROR : Tool-Rotation detected - this GRBL post only supports 3 Axis");
   error("Tool-Rotation detected but this GRBL post only supports 3 Axis");
   }

/**
   Calculates the two possible centers for a circle of a given radius that passes
   through two given points in a 2D plane.

   Original doc
   This code was generated with the help of ChatGPT AI
   Calculate the centers for the 2 circles passing through both points at the given radius
   if you ask chatgpt that ^^^ you will get incorrect code!
   if error then returns -9.9375 for all coordinates
   define points as var point1 = { x: 0, y: 0 };
   returns an array of 2 of those things comprising the 2 centers

   Gemini AI generated doc
   This is a geometric calculation. For any two distinct points on a circle and a given
   radius, there are generally two possible circles that satisfy these conditions. This
   function finds the centers of both.

   If the distance between `point1` and `point2` is greater than twice the radius
   (the diameter), no such circle can exist. In this case, the function returns
   two center points with coordinates set to a specific magic number (-9.9375)
   to indicate an error.

   The value -9.9375 is chosen specifically because it has an exact finite
   representation in binary floating-point numbers (unlike a number like 0.1).
   This allows the calling code to perform a direct and reliable equality check
   (e.g., `result == -9.9375`) to detect the error condition without worrying
   about floating-point inaccuracies.

   Note: The original author notes this code was generated with the help of AI.

   @param {{x: number, y: number}} point1 The first point on the circle's circumference.
   @param {{x: number, y: number}} point2 The second point on the circle's circumference.
   @param {number} radius The radius of the circle.
   @returns {Array<{x: number, y: number}>} An array containing two objects,
     each representing a possible center point with `x` and `y` coordinates.
     In case of an error, both points will have coordinates of -9.9375.
*/
function calculateCircleCenters(point1, point2, radius)
   {
   // Calculate the distance between the points
   var distance = Math.sqrt(  Math.pow(point2.x - point1.x, 2) + Math.pow(point2.y - point1.y, 2)  );
   if (distance > (radius * 2))
      {
      //-9.9375 is perfectly stored by doubles and singles and will pass an equality test
      center1X = center1Y = center2X = center2Y = -9.9375;
      }
   else
      {
      // Calculate the midpoint between the points
      var midpointX = (point1.x + point2.x) / 2;
      var midpointY = (point1.y + point2.y) / 2;

      // Calculate the angle between the line connecting the points and the x-axis
      var angle = Math.atan2(point2.y - point1.y, point2.x - point1.x);

      // Calculate the distance from the midpoint to the center of each circle
      var halfChordLength = Math.sqrt(Math.pow(radius, 2) - Math.pow(distance / 2, 2));

      // Calculate the centers of the circles
      var center1X = midpointX + halfChordLength * Math.cos(angle + Math.PI / 2);
      var center1Y = midpointY + halfChordLength * Math.sin(angle + Math.PI / 2);

      var center2X = midpointX + halfChordLength * Math.cos(angle - Math.PI / 2);
      var center2Y = midpointY + halfChordLength * Math.sin(angle - Math.PI / 2);
      }

   // Return the centers of the circles as an array of objects
   return [
      { x: center1X, y: center1Y },
      { x: center2X, y: center2Y }   ];
   }

/** 
 * given the 2 points and existing center, find a new, more accurate center
 * only works in x,y
 * point parameters are Vectors, this converts them to arrays for the calc
 * returns a Vector point with the revised center values in x,y, ignore Z
 */
function newCenter(p1, p2, oldcenter, radius)
   {
   // inputs are vectors, convert
   var point1 = { x: p1.x, y: p1.y };
   var point2 = { x: p2.x, y: p2.y };

   var newcenters = calculateCircleCenters(point1, point2, radius);
   if ((newcenters[0].x == newcenters[1].x) && (newcenters[0].y == -9.9375))
      {
      // error in calculation, distance between points > diameter
      return oldcenter;   
      }
   // now find the new center that is closest to the old center
   //writeComment("nc1 " + newcenters[0].x + " " + newcenters[0].y);
   nc1 = new Vector(newcenters[0].x, newcenters[0].y, 0); // note Z is not valid
   //writeComment("nc2 " + newcenters[1].x + " " + newcenters[1].y);
   nc2 = new Vector(newcenters[1].x, newcenters[1].y, 0);
   d1 = Vector.diff(oldcenter, nc1).length;
   d2 = Vector.diff(oldcenter, nc2).length;
   // return the new center that is closest to the old center
   if (d1 < d2)
      return nc1;
   else
      return nc2;
   }

/**
 * Recalculates the center point of an arc to correct for radius discrepancies.
 *
 * G-code controllers like GRBL are strict and require the distance (radius) from the
 * arc's center to its start point to be almost exactly equal to the distance from
 * the center to its end point. Due to floating-point inaccuracies or issues in the
 * source CAM data, these radii can sometimes differ, causing a "G2/G3 Radius to end
 * point mismatch" error on the machine.
 *
 * This function provides a geometric solution. It calculates a new center point that is
 * guaranteed to be equidistant from the provided start and end points.
 *
 * For arcs in vertical planes (ZX and YZ), it cleverly projects the 3D coordinates
 * onto a temporary 2D XY plane, performs the standard 2D circle center calculation
 * via the `newCenter` helper, and then maps the corrected 2D center back to the
 * original 3D plane.
 *
 * @param {Vector} start The Vector representing the arc's start point.
 * @param {Vector} end The Vector representing the arc's end point.
 * @param {Vector} center The original, potentially inaccurate, center point Vector.
 * @param {number} radius The nominal radius of the arc.
 * @param {number} cp The constant representing the circular plane (e.g., PLANE_XY, PLANE_ZX).
 * @returns {Vector} The recalculated, more accurate center point Vector.
*/   
function ReCenter(start, end, center, radius, cp)
   {
      var r1,r2,diff,pdiff;
   
   switch (cp)
      {
      case PLANE_XY:
         if (debugMode) writeComment('recenter XY');
         var nCenter = newCenter(start, end, center,  radius );
         // writeComment("old center " + center.x + " , " + center.y);
         // writeComment("new center " + nCenter.x + " , " + nCenter.y);
         center.x = nCenter.x;
         center.y = nCenter.y;
         center.z = (start.z + end.z) / 2.0;

         r1 = Vector.diff(start, center).length;
         r2 = Vector.diff(end, center).length;
         if (r1 != r2)
            {
            diff = r1 - r2;
            pdiff = Math.abs(diff / r1 * 100);
            if (pdiff  > 0.01)
               {
               if (debugMode) writeComment("R1 " + r1 + " r2 " + r2 + " d " + (r1 - r2) + " pdoff " + pdiff );
               }
            }
         break;
      case PLANE_ZX:
         if (debugMode) writeComment('recenter ZX');
         // generate fake x,y vectors
         var st = new Vector( start.x, start.z, 0);
         var ed = new Vector(end.x, end.z, 0)
         var ct = new Vector(center.x, center.z, 0);
         var nCenter = newCenter( st, ed, ct,  radius);
         // translate fake x,y values
         center.x = nCenter.x;
         center.z = nCenter.y;
         r1 = Vector.diff(start, center).length;
         r2 = Vector.diff(end, center).length;
         if (r1 != r2)
            {
            diff = r1 - r2;
            pdiff = Math.abs(diff / r1 * 100);
            if (pdiff  > 0.01)
               {
               if (debugMode) writeComment("ZX R1 " + r1 + " r2 " + r2 + " d " + (r1 - r2) + " pdoff " + pdiff );
               }
            }
         break;
      case PLANE_YZ:
         if (debugMode) writeComment('recenter YZ');
         var st = new Vector(start.z, start.y, 0);
         var ed = new Vector(end.z, end.y, 0)
         var ct = new Vector(center.z, center.y, 0);
         var nCenter = newCenter(st, ed, ct,  radius);
         center.y = nCenter.y;
         center.z = nCenter.x;
         r1 = Vector.diff(start, center).length;
         r2 = Vector.diff(end, center).length;
         if (r1 != r2)
            {
            diff = r1 - r2;
            pdiff = Math.abs(diff / r1 * 100);
            if (pdiff  > 0.01)
               {
               if (debugMode) writeComment("YZ R1 " + r1 + " r2 " + r2 + " d " + (r1 - r2) + " pdoff " + pdiff );
               }
            }
         break;
      }
   return center;
   }

/**
 * Checks if a file split is required based on the line count and triggers it if necessary.
 * This is intended to be called after a motion command, preferably a rapid move,
 * to ensure a safe resume point.
 *
 * @param {number} x The current X-coordinate, used to resume motion after the split.
 * @param {number} y The current Y-coordinate, used to resume motion after the split.
 * @param {number} z The current Z-coordinate, used to resume motion after the split.
 * @param {number} feed The current feed rate, used to resume motion after the split.
 * @param {boolean} isRapid A flag indicating if the last move was a rapid move.
 *   Splitting is only performed after a rapid move unless the line count exceeds the
 *   limit by more than 10%, in which case a split is forced.
 * @returns {boolean} Returns true if a file split was performed, otherwise false.
 */
function handleFileSplitting(x, y, z, feed, isRapid)
   {
   if (SPL.tapelines > 0 && SPL.linecnt > SPL.tapelines)
      {
      // Force a split if the line count exceeds the limit by 10% to prevent huge files, else wait for a safe rapid move.
      var forceSplit = SPL.linecnt > (SPL.tapelines * 1.1);
      if (isRapid || forceSplit)
         {
         if (forceSplit)
            writeComment('Forcing split: line count (' + SPL.linecnt + ') > 110% of limit (' + Math.round(SPL.tapelines * 1.1) + ').');
         else
            writeComment('Tapelines ' + SPL.tapelines + ' exceeded. Splitting file at rapid move.');
         SPL.linecnt = 0;
         splitHere(x, y, z, feed);
         return true; // A split occurred
         }
      }
   return false; // No split occurred
   }

/**
 * Handles the generation of circular (G2/G3) and helical arc moves.
 *
 * This function is a critical part of the post-processor, containing extensive logic
 * to prevent common "Arc Radius to End Point Mismatch" errors on GRBL controllers.
 * It employs a multi-step strategy to ensure valid G-code output:
 *
 * 1.  **Full Circle Check**: Immediately linearizes full 360-degree circles, which are
 *     not supported by IJK-center format G-code.
 * 2.  **Center Point Correction**: Adjusts the off-plane coordinate of the arc's center
 *     to be the average of the start and end points, which pre-emptively fixes many
 *     radius errors in helical moves.
 * 3.  **Radius Recalculation**: If a radius mismatch is detected between the start->center
 *     and end->center distances, it calls the `ReCenter` helper function to calculate a
 *     new, geometrically perfect center point.
 * 4.  **Strategic Linearization**: It will intentionally convert the arc to a series of
 *     small straight lines (`linearize()`) under specific conditions:
 *     - If the arc's radius is smaller than the tool's radius (and the property is enabled).
 *     - If it's a non-cutting (rapid) move during a laser or plasma operation.
 *     - If the arc is on a vertical plane (ZX/YZ) during a laser or plasma operation.
 * 5.  **G-Code Output**: If the arc is deemed safe, it generates the final G2/G3 command
 *     with the appropriate plane (G17/G18/G19) and IJK values.
 *
 * @param {boolean} clockwise True for a G2 (clockwise) arc, false for a G3 (counter-clockwise) arc.
 * @param {number} cx The X-coordinate of the arc's center point.
 * @param {number} cy The Y-coordinate of the arc's center point.
 * @param {number} cz The Z-coordinate of the arc's center point.
 * @param {number} x The X-coordinate of the arc's end point.
 * @param {number} y The Y-coordinate of the arc's end point.
 * @param {number} z The Z-coordinate of the arc's end point.
 * @param {number} feed The feed rate for the arc move.
 * @returns {void} This function does not return a value.
 */
function onCircular(clockwise, cx, cy, cz, x, y, z, feed)
   {
   var start = getCurrentPosition();
   var center = new Vector(cx, cy, cz);
   var end = new Vector(x, y, z);
   var cp = getCircularPlane();
   //writeComment("cp " + cp);

   if (isFullCircle())
      {
      writeComment("full circle");
      linearize(tolerance);
      return;
      }
   if (!OB.haveRapid && (OB.movestr == 'direct') )
      {
      // direct arc moves might as well be rapid since they are bracketed by rapids
      //writeComment("linearize direct move");
      gMotionModal.format(0);
      var chord =  Vector.diff(start,end).length;
      if (chord > toolRadius)
         var tol = toPreciseUnit(0.1,MM);
      else
         var tol = tolerance * 10;
      //writeComment("chord " + round(chord,3) + " " + round(tol,3) + " " + round(start.x,3) +":"+  round(start.y,3) + " : " + round(end.x,3) + " " + round(end.y,3) );
      linearize(tol);         // dont need high resolution arcs
      return;
      }
   // first fix the center 'height'
   // for an XY plane, fix Z to be between start.z and end.z
   switch (cp)
      {
      case PLANE_XY:
         center.z = (start.z + end.z) / 2.0; // doing this fixes most arc radius lengths
         break;                              // because the radius depends on the axial distance as well
      case PLANE_YZ:
         // fix X
         center.x = (start.x + end.x) / 2.0;
         break;
      case PLANE_ZX:
         // fix Y
         center.y = (start.y + end.y) / 2.0;
         break;
      default:
         writeComment("no plane");
      }
   // check for differing radii
   var r1 = Vector.diff(start, center).length;
   var r2 = Vector.diff(end, center).length;
   if ( (r1 != r2) && (r1 < toolRadius) ) // always recenter small arcs
      {
      if (debugMode)   
         {
         var diff = r1 - r2;
         var pdiff = Math.abs(diff / r1 * 100);
         writeComment("recenter");
         writeComment("r1 " + r1 + " r2 " + r2 + " d " + (r1 - r2) + " pdiff " + pdiff );
         }
      center = ReCenter(start, end, center, (r1 + r2) /2, cp);
      }

   // arcs smaller than bitradius always have significant radius errors, 
   // so get radius and linearize them (because we cannot change minimumCircularRadius here)
   // note that larger arcs still have radius errors, but they are a much smaller percentage of the radius
   // and GRBL won't care
   var rad = Vector.diff(start,center).length;  // radius to NEW Center if it has been calculated
   //DONE change this to always recenter for rad < toolRadius and toolDiam < 3/8", seems these conditions are too lax
   if ( (rad < toPreciseUnit(6, MM)) || OB.isPlasma)  // only for small arcs, dont need to linearize a 24mm arc on a 50mm tool
      if (properties.linearizeSmallArcs && (rad < toolRadius))
         {
         var tt = OB.powerOn ? tolerance : tolerance * 20; // if power is off on plasma then we are doing rapid motion and a very rough toolpath is fine
         if (debugMode) writeComment("linearizing arc radius " + round(rad, 4) + " toolRadius " + round(toolRadius, 3) + " tolerance " + tt);
         linearize(tt);
         if (debugMode) writeComment("done");
         return;
         }
   // not small and not a full circle, output G2 or G3
   if ((OB.isLaser || OB.isPlasma) && !OB.powerOn)
      {
      if (debugMode) writeComment("arc linearize rapid");
      linearize(tolerance * 20); // this is a rapid move so tolerance can be increased for faster motion and fewer lines of code
      if (debugMode) writeComment("arc linearize rapid done");
      }
   else
      switch (getCircularPlane())
         {
         case PLANE_XY:
            xOutput.reset();  // must always have X and Y
            yOutput.reset();
            // dont need to do ioutput and joutput because they are reference variables
            if (OB.isMill)
               writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(center.x - start.x, 0), jOutput.format(center.y - start.y, 0), feedOutput.format(feed));
            else
               {
               //zo = properties.UseZ ? zOutput.format(z) : "";
               zo = properties.UseZ ? (z < plasma.cutHeight) ? zOutput.format(plasma.cutHeight) :  zOutput.format(z) : "";
               writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zo, iOutput.format(center.x - start.x, 0), jOutput.format(center.y - start.y, 0), feedOutput.format(feed));
               }
            break;
         case PLANE_ZX:
            if (OB.isMill)
               {
               xOutput.reset(); // always have X and Z
               zOutput.reset();
               writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(center.x - start.x, 0), kOutput.format(center.z - start.z, 0), feedOutput.format(feed));
               }
            else
               linearize(tolerance);
            break;
         case PLANE_YZ:
            if (OB.isMill)
               {
               yOutput.reset(); // always have Y and Z
               zOutput.reset();
               writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(center.y - start.y, 0), kOutput.format(center.z - start.z, 0), feedOutput.format(feed));
               }
            else
               linearize(tolerance);
            break;
         default:
            linearize(tolerance);
         } //switch plane
   }

/**
 * Orchestrates the splitting of a G-code file when the line count limit is exceeded.
 *
 * This function manages the safe transition from one file to the next by generating
 * G-code to resume the toolpath at the exact point where the split occurred.
 *
 * The process involves setting a global flag (`SPL.forceSplit`) which is then
 * detected by the `onSection` handler to trigger the creation of a new file and
 * its header. After the new file is initiated, this function generates the
 * necessary G-code to safely resume the operation:
 * 1. A rapid move (G0) to the last known XY position at the operation's retract height.
 * 2. A feed move (G1) to plunge the tool back down to the last known Z-depth
 *    using the operation's plunge feed rate.
 *
 * @param {number} _x The X-coordinate where the split was triggered, used for the resume motion.
 * @param {number} _y The Y-coordinate where the split was triggered, used for the resume motion.
 * @param {number} _z The Z-coordinate where the split was triggered, used for the resume motion.
 * @param {number} _f The feed rate at the time of the split. Note: This parameter is currently
 *   unused; the plunge feed rate from the operation is used for the Z-resume move.
 * @returns {void} This function does not return a value.
 */
function splitHere(_x,_y,_z,_f)
   {
   // output footer
   if (debugMode) writeComment('splitHere: Splitting file');
   //onClose();
   // open new file
   SPL.forceSplit = true;
   // write header
   onSection();
   // goto x,y
   writeComment("Resume previous position");
   invokeOnRapid(_x, _y, Heights.retract);
   haveRapid = false;
   // goto z
   var sectionId = getCurrentSectionId();       // what is the number of this operation (starts from 0)
   var section = getSection(sectionId);         // what is the section-object for this operation
   var feed = section.getParameter("operation:tool_feedEntry"); // lead-in rate
   writeComment("Resume previous cut depth");
   gMotionModal.reset();
   invokeOnRapid(_x,_y,Heights.top);  // feed back to top as rapid
   haveRapid = false;
   onLinear(_x,_y,_z,feed);  // feed back to previous cut level at lead-in rate
   }   

/**
 * Handles cleanup and file closing at the end of a CAM operation (section).
 *
 * This function is called after all toolpath G-code for a section has been generated.
 * Its primary responsibility is to determine if the current output file should be
 * closed. This is crucial for multi-file generation (e.g., for tool changes).
 *
 * A file is closed under two conditions:
 * 1. It is the last section of the entire job.
 * 2. The `generateMultiple` property is enabled, and the next section uses a different tool.
 *
 * When a file is closed, this function calls `onClose()` to write the program footer
 * (e.g., M5, M30, return to home) and then closes the file stream. It also resets
 * motion and feed rate modals to ensure the next section starts with a clean state.
 *
 * @returns {void} This function does not return a value.
 */
function onSectionEnd()
   {
   writeln("");
   // writeBlock(gPlaneModal.format(17));
   if (isRedirecting())
      {
      // The file should be closed if this is the last section of the entire job,
      // OR if a tool change is about to happen (making it the last section for this file).
      var isLastSectionOfFile = isLastSection() ||
        (!isLastSection() && properties.generateMultiple && (tool.number != getNextSection().getTool().number));

      if (isLastSectionOfFile)
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

/**
 * Generates the final G-code sequence (footer) to safely end a program or file.
 *
 * This function is called to write the concluding commands for a G-code file.
 * It ensures the machine is left in a safe state by performing the following actions:
 *
 * For Milling Operations:
 * 1. Retracts the Z-axis to a safe machine coordinate using `writeZretract()` (G53 G0 Z...).
 * 2. Stops the spindle (M5) and coolant (M9).
 * 3. Moves the X and Y axes to a user-defined home position. This move can be in
 *    machine coordinates (G53) or work coordinates depending on the `gotoMCSatend` property.
 *
 * For Laser/Plasma Operations:
 * 1. Stops the power (M5) and coolant (M9).
 * 2. If `UseZ` is enabled, it retracts the Z-axis to a safe machine coordinate.
 * 3. For plasma, it also moves X and Y to the home position.
 *
 * The function concludes by writing the program end command (M30).
 *
 * @returns {void} This function does not return a value.
 */
function onClose()
   {
   xOutput.reset();
   yOutput.reset();
   gMotionModal.reset();
   writeBlock(gAbsIncModal.format(90));   // Set to absolute coordinates for the following moves
   if (OB.isMill)
      {
      gMotionModal.reset();  // for ease of reading the code always output the G0 words
      writeZretract();
      //writeBlock(gAbsIncModal.format(90), gFormat.format(53), gMotionModal.format(0), "Z" + xyzFormat.format(toPreciseUnit(properties.machineHomeZ, MM)));  // Retract spindle to Machine Z Home
      }
   writeBlock(mFormat.format(5));                              // Stop Spindle
   if (properties.hasCoolant)
      {
      writeBlock( setCoolant(0) );                           // Stop Coolant
      }
   //onDwell(properties.spindleOnOffDelay);                    // Wait for spindle to stop
   gMotionModal.reset();
   if (OB.isMill)
      {
      var g53 = '';
      if (properties.gotoMCSatend)    // go to MCS home
         g53 = gFormat.format(53);
      writeBlock(g53, gFormat.format(0),
                 "X" + xyzFormat.format(toPreciseUnit(properties.machineHomeX, MM)),
                 "Y" + xyzFormat.format(toPreciseUnit(properties.machineHomeY, MM)));
      }
   else     // laser
      {
      xOutput.reset();
      yOutput.reset();
      if (properties.gotoMCSatend)    // go to MCS home
         {
         if (properties.UseZ)
            writeBlock(  gFormat.format(53), gFormat.format(0), zOutput.format(toPreciseUnit(properties.machineHomeZ, MM)) );
         writeBlock(  gFormat.format(53), gFormat.format(0),
                     xOutput.format(toPreciseUnit(properties.machineHomeX, MM)),
                     yOutput.format(toPreciseUnit(properties.machineHomeY, MM)) );
         }
      else
         {
         if (properties.UseZ)
            writeBlock(  gFormat.format(53), gFormat.format(0), zOutput.format(toPreciseUnit(properties.machineHomeZ, MM)) );
         writeBlock( gFormat.format(0), xOutput.format(0), yOutput.format(0));
         }
      }
   writeBlock(mFormat.format(30));  // Program End
   //writeln("%");                    // EndOfFile marker
   }

/**
 * Finalizes the output when multiple files are generated by creating a manifest file.
 *
 * This function is called once at the very end of the entire post-processing job.
 * Its main purpose is to improve usability when the job is split into multiple
 * G-code files (due to tool changes or line count limits).
 *
 * It performs the following steps for multi-file jobs:
 * 1. It takes the first generated file (which has the base program name).
 * 2. It copies this file to its final, numbered name (e.g., `program.01ofX.gcode`).
 * 3. It deletes the original, un-numbered file.
 * 4. It creates a new text file with the original program name (e.g., `program.gcode`)
 *    that acts as a manifest, containing a list of all the numbered G-code files
 *    that were created for the job.
 *
 * This leaves the user with a clear list of files to run on their machine,
 * eliminating the ambiguity of which file to run first.
 *
 * @returns {void} This function does not return a value.
 */
function onTerminate()
   {
   // If we are generating multiple files, copy first file to add # of #
   // Then remove first file and recreate with file list - sharmstr
   var outputPath = getOutputPath();
   var programFilename = FileSystem.getFilename(outputPath);
   if (filesToGenerate > 1)
      {
      
      var outputFolder = FileSystem.getFolderPath(getOutputPath());
      // make sure file is closed
      if (isRedirecting())
         closeRedirection();
      var newname = makeFileName(1);
      FileSystem.copyFile(outputPath, newname);
      FileSystem.remove(outputPath);
      var file = new TextFile(outputFolder + "\\" + programFilename, true, "ansi");
      file.writeln("The following gcode files were Created: ");
      var fname;
      for (var i = 0; i < filesToGenerate; ++i)
         {
         fname = makeFileName(i + 1);
         file.writeln(fname);
         }
      if (properties.splitLines > 0)   
         file.writeln("A total of " + filesToGenerate + " files were written.");
      file.close();
      }
   // from haas nextgen post, auto output a setup sheet
/*   
   this does not work as we cannot find the post in the personal post folder unless user tells us what it is
   //var outputPath = getOutputPath();
   warning("outputpath " + outputPath);
   
   //var programFilename = FileSystem.getFilename(outputPath);
   warning("programFilename " + programFilename);
   
   var programSize = FileSystem.getFileSize(outputPath);
   warning("programSize " + programSize);

   var pfolder = getConfigurationPath(); // path to current post
   warning('pfolder ' + pfolder);
   
   var postPath = findFile(".\\setup-sheet.cps");
   warning("postpath " + postPath);

   var intermediatePath = getIntermediatePath();
   debug("intermediatePath " + intermediatePath);
   var a = "--property unit " + ((unit == IN) ? "0" : "1"); // use 0 for inch and 1 for mm
   if (programName) 
      {
      a += " --property programName \"'" + programName + "'\"";
      }
   if (programComment) 
      {
      a += " --property programComment \"'" + programComment + "'\"";
      }
   a += " --property programFilename \"'" + programFilename + "'\"";
   a += " --property programSize \"" + programSize + "\"";
   a += " --noeditor --log temp.log \"" + postPath + "\" \"" + intermediatePath + "\" \"" + FileSystem.replaceExtension(outputPath, "html") + "\"";
   debug(a);
   */
   //execute(getPostProcessorPath(), a, false, "");
   //executeNoWait("start", "\"" + FileSystem.replaceExtension(outputPath, "html") + "\"", false, "");
   }

/**
 * Handles manual NC commands inserted into the CAM setup.
 *
 * This function acts as an event handler for specific, non-toolpath commands
 * like "Program Stop", "Power On", or "Power Off". It translates these abstract
 * commands from the CAM system into concrete G-code sequences.
 *
 * Key command translations include:
 * - `COMMAND_STOP`: Issues a program stop (M0).
 * - `COMMAND_POWER_OFF`: Sets the internal power state to off and issues an M5
 *   command, with an optional post-cut delay for plasma.
 * - `COMMAND_POWER_ON`: This is the most complex handler. It sets the internal
 *   power state to on. For plasma operations with touch-off enabled, it
 *   generates a full probing cycle (G38.2) to find the material surface, sets
 *   the work offset (G10 L20), and then moves to the pierce height. For other
 *   laser/plasma operations, it moves to the pierce height before issuing the
 *   M3 command to turn the beam/torch on.
 *
 * @param {Command} command The command constant from the post-processor API,
 *   such as `COMMAND_STOP`, `COMMAND_POWER_ON`, etc.
 * @returns {void} This function does not return a value.
 */
function onCommand(command)
   {
   if (debugMode) writeComment("onCommand " + command);
   switch (command)
      {
      case COMMAND_STOP: // - Program stop (M00)
         writeComment("Program stop M00");
         writeBlock(mFormat.format(0));
         break;
      case COMMAND_OPTIONAL_STOP: // - Optional program stop (M01)
         writeComment("Optional program stop M01");
         writeBlock(mFormat.format(1));
         break;
      case COMMAND_END: // - Program end (M02)
         writeComment("Program end M02");
         writeBlock(mFormat.format(2));
         break;
      case COMMAND_POWER_OFF:
         if (debugMode) writeComment("power off");
         if (!OB.haveRapid)
            writeln("");
         OB.powerOn = false;
         if (OB.isPlasma || (OB.isLaser && (OB.cuttingMode == 'cut')) )
            {
            writeBlock(mFormat.format(5));
            if (properties.plasma_postcutdelay > 0)
               onDwell(properties.plasma_postcutdelay);
            }
         break;
      case COMMAND_POWER_ON:
         if (debugMode) writeComment("power ON");
         if (!OB.haveRapid)
            writeln("");
         OB.powerOn = true;
         if (OB.isPlasma || OB.isLaser)
            {
            if (properties.UseZ)
               {
               if (properties.plasma_usetouchoff && OB.isPlasma)
                  {
                  // probe for plasma touchoff
                  writeln("");
                  writeBlock( "G38.2", zOutput.format(toPreciseUnit(-plasma_probedistance, MM)), feedOutput.format(toPreciseUnit(plasma_proberate, MM)));
                  if (debugMode) writeComment("touch offset "  + xyzFormat.format(properties.plasma_touchoffOffset) );
                  writeBlock( gMotionModal.format(10), "L20 P0", zOutput.format(toPreciseUnit(-parseFloat(properties.plasma_touchoffOffset), MM)) );
                  feedOutput.reset();
                  // force a G0 to existing position after the probe because this appears to avoid a GRBL bug in small arcs when arcing
                  // from an existing position after probing.
                  xOutput.reset();
                  yOutput.reset();
                  var cpos = getCurrentPosition();
                  // after probing grbl appears to have forgotten the current position so we need to reset it else following moves are weird, so force X and Y
                  //writeComment(plasma.pierceHeight);
                  writeBlock(gMotionModal.format(0), xOutput.format(cpos.x), yOutput.format(cpos.y), zOutput.format(plasma.pierceHeight), " ; force position after probe and move to pierceheight");
                  }
               else   
                  // move to pierce height
                  var _zz = zOutput.format(plasma.pierceHeight);
                  var _msg = '';
                  if (debugMode)
                     _msg = " ; pierce height";
                  if (_zz)
                     writeBlock( gMotionModal.format(0), _zz, _msg );
               }
            if (OB.isPlasma || (OB.cuttingMode == 'cut') || (clnt))
               writeBlock(mFormat.format(3), sOutput.format(OB.power), clnt);
            }
         break;
      default:
         if (debugMode) writeComment("onCommand not handled " + command);
      }
   // for other commands see https://cam.autodesk.com/posts/reference/classPostProcessor.html#af3a71236d7fe350fd33bdc14b0c7a4c6
   if (debugMode) writeComment("onCommand end");
   }

/**
 * Handles specific CAM parameters passed during post-processing.
 *
 * This function is a critical event handler that is called by the post-processor
 * engine whenever it encounters specific named parameters within an operation. It
 * acts as a switchboard to capture and process settings that are not part of the
 * standard toolpath data, such as heights, feed rates for special moves, and
 * action triggers.
 *
 * Key responsibilities include:
 * - Capturing essential height values like `retractHeight`, `clearanceHeight`, and `topHeight`.
 * - Configuring parameters for plasma and laser operations, including `pierceTime`,
 *   `cutHeight`, and `leadinRate`.
 * - Setting up feed rates for probing cycles.
 * - Executing special action sequences, most notably the "pierce" action, which
 *   triggers a dwell followed by a plunge to the cutting height.
 *
 * @param {string} name The unique string identifier for the parameter, e.g.,
 *   "operation:retractHeight value", "movement:lead_in", or "action".
 * @param {*} value The value associated with the parameter, which can be a
 *   number, string, or other type.
 * @returns {void} This function does not return a value.
 */
function onParameter(name, value)
   {
   //if (debugMode) writeComment("onParameter =" + name + "= " + value);
   switch (name)
      {
//2073: onParameter('operation:tool_feedCutting', 1270)
      case "operation:tool_feedCutting" :
         Feeds.cutting =  value;
         break;  
//2077: onParameter('operation:tool_feedEntry', 1270)
      case "operation:tool_feedEntry" :
         Feeds.entry =  value;
         break;
//2079: onParameter('operation:tool_feedExit', 1270)
      case "operation:tool_feedExit" :
         Feeds.exit =  value;
         break;
//2081: onParameter('operation:tool_feedTransition', 1270)
//2083: onParameter('operation:tool_feedRamp', 635)
//2085: onParameter('operation:tool_feedPlunge', 635)
//2089: onParameter('operation:tool_feedRetract', 635)

      case "operation:retractHeight_value":
         Heights.retract = value;
         if (debugMode) writeComment("onparameter - Heights.retract = " + round(Heights.retract, 3));
         break;
      case "operation:clearanceHeight_value":
         Heights.clearance = value;
         if (debugMode) writeComment("onparameter - Heights.clearance = " + round(Heights.clearance, 3));
         break;
      case "movement:lead_in":
         plasma.leadinRate = toPreciseUnit(value,MM);
         if (debugMode) writeComment("onparameter - leadinRate set " + round(plasma.leadinRate,1) + " unit " + unit);
         break;
      case "operation:topHeight_value":
         Heights.top = value;
         if (debugMode) writeComment("onparameter - Heights.top set " + Heights.top);
         break;
      case "operation:cuttingMode":
         OB.cuttingMode = value;
         if (debugMode) writeComment("onparameter - cuttingMode set " + OB.cuttingMode);
         if (OB.cuttingMode.indexOf('cut') >= 0) // simplify later logic, auto/low/medium/high are all 'cut'
            OB.cuttingMode = 'cut';
         if (OB.cuttingMode.indexOf('auto') >= 0)
            OB.cuttingMode = 'cut';
         break;
      case "operation:tool_cutHeight": // laser
         var msg = '';
         if (Heights.top != 0)
            {
            plasma.cutHeight = Heights.top;
            msg = ' = Heights.top';
            plasma.mode = 1;
            }
         else
            {
            if (OB.isPlasma)
               {
               plasma.cutHeight =  value;
               msg = ' = tool.cutHeight';
               }
            else
               {
               plasma.cutHeight =  0; // laser cut height is always 0
               msg = ' =0_for_laser';
               }
            plasma.mode = 2;
            }
         if (debugMode) writeComment("onparameter - cutHeight set " + plasma.cutHeight + msg);
         break;
      case "operation:tool_pierceTime": //laser
         msg = ' = tool_pierceTime';
         if (properties.spindleOnOffDelay > 0)
            {
            plasma.pierceTime = properties.spindleOnOffDelay;
            msg = ' = spindleonoffdelay';
            }
         else
            plasma.pierceTime = value;
         if (debugMode) writeComment("onparameter - pierceTime set " + plasma.pierceTime + msg);
         break;
      case "action": //plasma/laser
         if (value == 'pierce')
            {
            if (OB.isLaser && !properties.UsePierce)
               return;
            if (debugMode) writeComment('action pierce');
            onDwell(plasma.pierceTime);
            if (properties.UseZ) // done a probe and/or pierce, now lower to cut height
               {
               if (OB.isPlasma)
                  zOutput.reset();
               var _zz = zOutput.format(plasma.cutHeight);
               if (_zz)
                  {
                  if (debugMode) writeComment('lower to cutheight');
                  writeBlock( gMotionModal.format(1), _zz, feedOutput.format(plasma.leadinRate) );
                  gMotionModal.reset();
                  }
               }
            if (debugMode) writeComment('action pierce done');
            }
         break;
      case "operation:tool_feedProbeLink":
         PRB.feedProbeLink = value;
         if (debugMode) writeComment("onparameter - feedProbeLink set " + PRB.feedProbeLink);
         break;
      case "operation:tool_feedProbeMeasure":
         PRB.feedProbeMeasure = value;
         if (debugMode) writeComment("onparameter - feedProbeMeasure set " + PRB.feedProbeMeasure);
         break;
      case "operation:probeWorkOffset":
         if (value > 0)
            warning("WARNING " + 'You set a probe *Overide Driving WCS* but I dont know how to do that yet');
         break;
      case "probe-output-work-offset":
         PRB.probe_output_work_offset = value;
         if (debugMode) writeComment("onparameter - probe_output_work_offset set " + PRB.probe_output_work_offset);
         break;
      }
   }

function round(num, digits)
   {
   return toFixedNumber(num, digits, 10)
   }

function toFixedNumber(num, digits, base)
   {
   var pow = Math.pow(base || 10, digits); // cleverness found on web
   return Math.round(num * pow) / pow;
   }

/**
 * set the coolant mode from the tool value
 * changed 2023 - returns a string rather than writing the block itself
 *
 * Translates a numeric coolant code into the corresponding G-code M-commands.
 *
 * This function takes a numeric code representing the desired coolant state, as
 * defined in the Fusion 360 tool library, and returns a string with the
 * appropriate M-code(s) to send to the GRBL controller.
 *
 * It maintains an internal state (`coolantIsOn`) to avoid sending redundant
 * commands and to correctly handle transitions between different coolant types
 * (e.g., turning off flood before turning on mist).
 *
 * The valid input codes are:
 * - `0`: Coolant Off (M9)
 * - `1`: Flood Coolant On (M8)
 * - `2`: Mist Coolant On (M7)
 * - `7`: Both Flood and Mist On (M8 M7)
 *
 * @param {number} coolval The numeric code for the desired coolant state.
 * @returns {string} A string containing the required M-code(s) (e.g., "M8", "M9"),
 *   or an empty string if no command is necessary.
 */
function setCoolant(coolval)
   {
   var cresult = '';

   if ( debugMode) writeComment("setCoolant " + coolval);
   // 0 if off, 1 is flood, 2 is mist, 7 is both
   switch (coolval)
      {
      case 0:
         if (coolantIsOn != 0)
            cresult = mFormat.format(9); // off
         coolantIsOn = 0;
         break;
      case 1:
         if (coolantIsOn == 2)
            cresult = mFormat.format(9); // turn mist off
         cresult = cresult + mFormat.format(8); // flood
         coolantIsOn = 1;
         break;
      case 2:
         //writeComment("Mist coolant on pin A3. special GRBL compile for this.");
         if (coolantIsOn == 1)
            cresult = mFormat.format(9); // turn flood off
         cresult += ' ' + mFormat.format(7); // mist
         coolantIsOn = 2;
         break;
      case 7:  // flood and mist
         cresult = mFormat.format(8) ; // flood
         cresult += ' ' + mFormat.format(7); // mist
         coolantIsOn = 7;
         break;
      default:
         var cmsg = "WARNING " + "Coolant option not understood: " + coolval;
         warning(cmsg);
         writeComment(cmsg);
         coolantIsOn = 0;
      }
   if ( debugMode) writeComment("setCoolant end " + cresult);
   return cresult;
   }

/**
   make a numbered filename
   will adjust for splitlines setting
   @param index the number of the file, from 1
*/
function makeFileName(index)
   {
   debug("makefilename " + index)   
   var fullname = getOutputPath();
   debug("   fullname " + fullname);
   //fullname = fullname.replace(' ', '_'); // messes with spaces in paths!
   var filenamePath;
   if (properties.splitLines > 0 )
      // since we don't know the final file count, dont say the wrong thing
      filenamePath = FileSystem.replaceExtension(fullname, fileIndexFormat.format(index) + "ofMany" + "." + extension);
   else
      filenamePath = FileSystem.replaceExtension(fullname, fileIndexFormat.format(index) + "of" + filesToGenerate + "." + extension);
   var filename = FileSystem.getFilename(filenamePath);
   debug("   filename " + filename);
   return filenamePath;
   }

function onCycle()
   {
   if (debugMode) writeComment('onCycle')   ;
   writeBlock(gPlaneModal.format(17));
   }

function onCycleEnd()
   {
   if (debugMode) writeComment('onCycleEnd');
   if (isProbeOperation())
      {
      zOutput.reset();
      gMotionModal.reset();
      //writeZretract();
      }   
   }      

/**
 * probe X from left or right
 *
 * Generates G-code for a single-axis probing cycle along the X-axis.
 *
 * This function is called by `onCyclePoint` for the "probing-x" cycle. It performs
 * a two-stage (fast, then slow) probe to accurately find the edge of a workpiece
 * in the X direction and sets the work coordinate system accordingly.
 *
 * The probing direction (positive or negative X) is determined by the `cycle.approach1`
 * property. The routine uses several other properties from the global `cycle` object,
 * such as `probeClearance`, `probeOvertravel`, `depth`, and `feedrate`.
 *
 * The process is as follows:
 * 1. Move to the initial Z height (`z`).
 * 2. Switch to relative motion (G91).
 * 3. Move down to the probing depth (`cycle.depth`).
 * 4. Perform a fast probe (G38.2) towards the workpiece.
 * 5. Retract slightly off the surface.
 * 6. Perform a slower, more accurate re-probe.
 * 7. Set the X-axis of the current work offset (G10 L20), compensating for the tool radius.
 * 8. Retract away from the workpiece.
 * 9. Switch back to absolute motion (G90).
 * 10. Return to the initial X and Z coordinates.
 *
 * @param {number} x The initial X-coordinate for the cycle point.
 * @param {number} y The initial Y-coordinate for the cycle point (used for positioning).
 * @param {number} z The retract Z-coordinate for the cycle.
 * @returns {void}
 */
function probeX(x,y,z)
   {
      var dir = 0;

   writeComment('probeX : ' + x + " " + y + " " + z);   
   switch(cycle.approach1) 
      {
      case "positive":  // probing +X toward stock
         writeComment('probe X positive');
         dir = 1;
         break;
      case "negative": /// probing -X toward stock
         writeComment('probe X negative');
         dir = -1;
         break;
      }
   // current position half way along Y,  -x/+x away from stock by probeClearance+tradius, Z=cycle.retract
   var _z = zOutput.format(z); // probe retract height
   writeBlock(gMotionModal.format(0), _z);
   writeBlock(gAbsIncModal.format(91), " ; relative moves");  // all relative moves
   // move Z down to cycle depth
   _z = zOutput.format(-cycle.depth);
   writeBlock(_z);
   // probe probeClearance + overtravel in dir
   var _x = xOutput.format( dir * (cycle.probeClearance + cycle.probeOvertravel) );
   var _f = feedOutput.format(cycle.feedrate);
   writeBlock(gProbeModal.format(38.2), _x, _f, " ; probe fast");
   // retract a little
   writeBlock(gMotionModal.format(0), xOutput.format(-dir * (cycle.probeOvertravel + toolRadius) ) ," ; retract");
   //reprobe slower
   var _f = feedOutput.format(PRB.feedProbeMeasure);
   writeBlock(gProbeModal.format(38.2), _x, _f, " ; probe slow");
   // setzero
   _p = pWord.format(PRB.probe_output_work_offset);
   writeBlock(gMotionModal.format(10), "L20", _p, xOutput.format(-dir * toolRadius));
   // move X away a bit, relative!
   _x = xOutput.format(-dir * cycle.probeClearance);
   writeBlock(gMotionModal.format(0), _x);   
   // G90
   writeBlock(gAbsIncModal.format(90), " ; absolute moves");
   // retract Y and  Z to cycleYZ 
   _z = zOutput.format(z);
   writeBlock(gMotionModal.format(0), xOutput.format(x), _z);
   writeComment('probeX finished');
   }   

/**
 * same as for X, but for Y
 * @param {number} x The initial X-coordinate for the cycle point.
 * @param {number} y The initial Y-coordinate for the cycle point.
 * @param {number} z The retract Z-coordinate for the cycle.
 * @returns {void}
*/
function probeY(x,y,z)
   {
   //move to Y-cycle.probeClearance   feedrate(tool_feedProbeLink)
      var dir = 0;

   writeComment('probeY : ' + x + " " + y + " " + z);   
   switch(cycle.approach1) 
      {
      case "positive":  // probing +Y toward stock
         writeComment('probe Y positive');
         dir = 1;
         break;
      case "negative": /// probing -y toward stock
         writeComment('probe Y negative');
         dir = -1;
         break;
      }
   // current position half way along X,  -y away from stock by probeClearance+radius, Z=cycle.retract
   var _z = zOutput.format(z); // probre retract height
   writeBlock(gMotionModal.format(0), _z);
   writeBlock(gAbsIncModal.format(91));  // all relative moves
   // move Z down to cycle depth
   _z = zOutput.format(-cycle.depth);
   writeBlock(_z);
   // probe probeClearnace + overtravel in dir
   var _y = yOutput.format( dir * (cycle.probeClearance + cycle.probeOvertravel) );
   var _f = feedOutput.format(cycle.feedrate);
   writeBlock(gProbeModal.format(38.2), _y, _f, " ; probe fast");
   // retract a little
   writeBlock(gMotionModal.format(0), yOutput.format(-dir * cycle.probeOvertravel) ," ; retract");
   //reprobe slower
   var _f = feedOutput.format(PRB.feedProbeMeasure);
   writeBlock(gProbeModal.format(38.2), _y, _f, " ; probe slow");
   // setzero
   _p = pWord.format(PRB.probe_output_work_offset);
   writeBlock(gMotionModal.format(10), "L20", _p, yOutput.format(-dir * toolRadius));
   // move Y away a bit, relative!
   _y = yOutput.format(-dir * cycle.probeClearance);
   writeBlock(gMotionModal.format(0), _y);   
   // G90
   writeBlock(gAbsIncModal.format(90));
   // retract Y and  Z to cycleYZ 
   _z = zOutput.format(z);
   writeBlock(gMotionModal.format(0), yOutput.format(y), _z);
   writeComment('probeY finished');
   }

/**
 * same as for X and Y but for Z
 * always probes in negative direction
 * @param {number} x The initial X-coordinate for the cycle point.
 * @param {number} y The initial Y-coordinate for the cycle point.
 * @param {number} z The retract Z-coordinate for the cycle.
 * @returns {void}
 */
function probeZ(x,y,z)   
   {
   writeComment('probeZ: ' + x + " " + y + " " + z);         
   // we are at nominalZ + cycle.clearance, center of stock
   // probe down by -(cycle.clearance + cycle.probeOverTravel)
   writeBlock(gAbsIncModal.format(91));  // all relative moves
   var _z = zOutput.format(-(cycle.clearance + cycle.probeOvertravel));
   var _f = feedOutput.format(cycle.feedrate);
   // probe fast
   writeBlock(gProbeModal.format(38.2), _z, _f, " ; probe fast");
   // retract
   _z = zOutput.format(cycle.probeOvertravel);
   writeBlock(gMotionModal.format(0) , _z);
   // reprobe slow
   _z = zOutput.format(-(cycle.clearance + cycle.probeOvertravel));
   _f = feedOutput.format(PRB.feedProbeMeasure);
   writeBlock(gProbeModal.format(38.2), _z, _f, " ; probe slow");
   // set WCS
   _p = pWord.format(PRB.probe_output_work_offset);
   writeBlock(gMotionModal.format(10), "L20", _p, zOutput.format(0));
   // raise Z relative
   _z = zOutput.format(cycle.retract);
   writeBlock(gMotionModal.format(0) , _z);
   writeBlock(gAbsIncModal.format(90));  // absolute
   _z = zOutput.format(cycle.clearance);
   writeBlock(gMotionModal.format(0) , _z);
   writeComment('probe Z end');
   }

/**
 * Main event handler for canned cycles, routing them to the appropriate G-code generation logic.
 *
 * This function is called for each point within a canned cycle (e.g., each hole in a
 * drilling pattern or each point in a probing routine). It acts as a central switchboard,
 * examining the global `cycleType` variable to determine how to process the provided
 * coordinates.
 *
 * It provides custom implementations for specific cycles supported by this post-processor,
 * including:
 * - Single-axis probing (`probing-x`, `probing-y`, `probing-z`).
 * - XY outer corner probing (`probing-xy-outer-corner`).
 * - Counter-boring (`counter-boring`), with specific handling for the dwell time.
 *
 * For recognized but unsupported cycles, it issues a warning to the user.
 *
 * For all other standard cycles (like drilling, tapping, etc.), it delegates to the
 * `expandCyclePoint` function, which translates the cycle into a series of basic
 * G0 and G1 linear moves. This ensures broad compatibility for drilling operations.
 * 
 * handles probe operations since there are many of them and only some can be supported on BlackBox 4X
 * Remember to expand unsupported cycles which will handle drilling cycles for us.
 *
 * @param {number} x The X-coordinate of the current cycle point (e.g., center of a hole).
 * @param {number} y The Y-coordinate of the current cycle point.
 * @param {number} z The Z-coordinate representing the bottom of the hole or final depth.
 * @returns {void} This function does not return a value.
 */
function onCyclePoint(x, y, z)
   {
   if (debugMode) writeComment('onCyclePoint: ' + x + " " + y + " " + z);
   switch (cycleType)
      {
      case "probing-x":
         writeComment('probing-x');
         probeX(x,y,z);
         break;
      case "probing-y":
         writeComment('probing-y');
         probeY(x,y,z);
         break;
      case "probing-z":
         writeComment('probing-z');
         probeZ(x,y,z);
         break;
      case "probing-xy-outer-corner":
         writeComment("probing-xy-outer-corner start");
         // do this by using probex and probey
         // we are at -clearance,-clearance,clearance
         // position for X probe
         writeBlock(gMotionModal.format(0), yOutput.format(cycle.probeClearance));
         probeX(x,cycle.probeClearance,z);
         invokeOnRapid(x,y,z);
         haveRapid = false;
         // position for Y probe
         writeBlock(gMotionModal.format(0), xOutput.format(cycle.probeClearance));
         probeY(cycle.probeClearance,y,z);
         invokeOnRapid(x,y,cycle.clearance);
         haveRapid = false;
         writeComment("probing-xy-outer-corner complete");
         break;
      case "probing-xy-circular-boss":
         writeComment('probing-xy-circular-boss');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-xy-circular-hole":
         writeComment('probing-xy-circular-hole');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-xy-circular-partial-boss":
         writeComment('probing-xy-circular-partial-boss');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-xy-circular-partial-hole":
         writeComment('probing-xy-circular-partial-hole');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-xy-circular-hole-with-island":
         writeComment('probing-xy-circular-hole-with-island');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-xy-circular-partial-hole-with-island":
         writeComment('probing-xy-circular-partial-hole-with-island');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-xy-rectangular-boss":
         writeComment('probing-xy-rectangular-boss');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-xy-rectangular-hole":
         writeComment('probing-xy-rectangular-hole');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-xy-rectangular-hole-with-island":
         writeComment('probing-xy-rectangular-hole-with-island');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-x-wall":
         writeComment('probing-x-wall');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-x-channel":
         writeComment('probing-x-channel');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-x-channel-with-island":
         writeComment('probing-x-channel-with-island');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-y-wall":
         writeComment('probing-y-wall');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-y-channel":
         writeComment('probing-y-channel');
         warning(cycleType + ' not supported in this version');
         break;
      case "probing-y-channel-with-island":
         writeComment('probing-y-channel-with-island');
         warning(cycleType + ' not supported in this version');
         break;
      case "counter-boring"   :  // counterbore with dwell - the expansion does not print the P word with seconds
         writeComment('Counterboring');
         var _x = xOutput.format(x);
         var _y = yOutput.format(y);
         zOutput.reset();
         var hclr = zOutput.format(cycle.clearance);  // clearance height
         var hret  = zOutput.format(cycle.retract);   // retract height
         var _z = zOutput.format(z);                  // drill depth
         var dwell = "P" + secFormat.format(cycle.dwell);  // dwell length in seconds
         var feed = feedOutput.format(cycle.feedrate);
         if (debugMode) writeComment('counter-boring cycle '+_x+_y+_z + dwell+feed);
         if (_x || _y)
            writeBlock(gFormat.format(0), _x,_y);   // G0 to xy
         if (hret)
            writeBlock(gFormat.format(0), hret);    // G0 to Heights.retract
         
         writeBlock(gMotionModal.format(1),_z,feed);  // G1 to drill depth
         if (cycle.dwell > 0)
            onDwell(cycle.dwell);
         
         writeBlock(gMotionModal.format(0), hclr);    // G0 to clearance height
         writeComment('Counterbore end');
         break;
      default:
         writeComment('Expanding cycle ' + cycleType);
         expandCyclePoint(x, y, z);
         writeComment('Expanding cycle end');
         return;
      }
   }

/// set mill to true and isplasma & islaser to false
function setMill()
   {
   OB.isMill = true;
   OB.isPlasma = OB.isLaser = false;
   }

/// set laser
function setLaser()
   {
   OB.isLaser = true;
   OB.isPlasma = OB.isMill = false;
   }

/// set plasma
function setPlasma()
   {
   OB.isPlasma = true;
   OB.isMill = OB.isLaser = false;
   }

/**
 * Sets the global operation type flags (OB.isMill, OB.isLaser, OB.isPlasma)
 * based on the provided tool's type. This function centralizes the logic for
 * identifying the nature of the current CAM operation.
 *
 * @param {object} tool The Fusion 360 tool object for the current operation.
 * @returns {void}
 */
function setOperationType(tool) 
   {
   switch (tool.type) 
      {
      case TOOL_LASER_CUTTER:
         setLaser();
         break;
      case TOOL_WATER_JET:
      case TOOL_PLASMA_CUTTER:
         setPlasma();
         break;
      default: // Includes TOOL_PROBE and all milling tools
         setMill();
         break;
      }
   }

/*
   true if NEAR greater or equal to target. 
   true if val >= target - 0.1MM        saves us doing the math in many places   
   @PARAM val the value
   @PARAM target the target height
*/
function nearGE(val, target)
   {
   target = target - toPreciseUnit(0.1,MM);      
   return val >= target;
   }