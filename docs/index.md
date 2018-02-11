
<div style="text-align:center"> 
  <h3>What is ObjectFinder?</h3>

<div style="text-align:center"><img src ="https://lucadellasantina.github.io/ObjectFinder/app_icon_big.png"/></div>

ObjectFinder is a MATLAB® app that allows you to recognize thousands of small structures, such as synapses in neuronal tissue, within a three-dimensional image volume. <br>

ObjectFinder was originally developed for neuroscience research purposes, where it is able to detect fluorescently-labeled synapses in neuronal image stacks acquired using confocal or super-resolution microscopes.

<div style="text-align:center"><img src ="https://lucadellasantina.github.io/ObjectFinder/Screenshot_heatmap.png" width="60%"/></div>

  <h3>Free as in freedom</h3>

ObjectFinder is licensed under <a href="https://www.gnu.org/licenses/gpl-3.0.en.html">GNU General Public License v3.</a>
This strong copyleft license ensures you will always have the right to obtain ObjectFinder for free, view and modify the source code to review its functionality and improve its features.
<div style="text-align:center"><img src ="https://lucadellasantina.github.io/ObjectFinder/logo_gplv3.png"/></div>

We strongly believe that software developed for data analysis in scientific research must:<br>

Be open source, to ensure the highest level of reproducibility of your science.<br>
Be free of charge for everyone, to ensure no divide of opportunities is built between scientists who can and those who cannot afford expensive software packages to produce meaningful scientific discoveries with their research.

<div style="text-align:center"><img src ="https://lucadellasantina.github.io/ObjectFinder/logo_open_source.png" width="100"/></div>

  <h3>Tuned for speed!</h3>

ObjectFinder can search hundred thosands objects in a matter of minutes by taking full advantage of your computer's CPU cores, this is achieved by implementing multi-threaded search inside the 3D volume. 

<div style="text-align:center"><img src ="https://lucadellasantina.github.io/ObjectFinder/speed.png" width="80" height="80"/></div>

For a typical workstation with an 8-core CPU this means an 8X fold faster speed compared to a classic app running on the same computer!

  <h3>Multiplatform architecture</h3>

Whether your workstation relies on Microsoft Windows, macOS or Linux, ObjectFinder can run on your computer since it relies only on core Matlab functions.<br>

<div style="text-align:center"><img src ="https://lucadellasantina.github.io/ObjectFinder/logo_platforms.png" width="75%"/></div>

Having a single codebase for all platforms makes developing new features as well as fixing bugs a much faster and enjoyable journey.

  <h3>Seamlessly integrates with Bitplane Imaris®</h3>
  
ObjectFinder can display detected objects in Imaris® to take full advantage of Imaris advanced 3D rendering capabilities. You can visually add, remove or filter objects by visual inspection against the original signal and export them back to ObjectFinder for further processing.

  <h3>Export results to Microsoft Excel®</h3>

Analysis results can be exported to Excel spreadsheets for further elaboration or plotting using your favorite data analysis application.

<div style="text-align:center"><img src ="https://lucadellasantina.github.io/ObjectFinder/Screenshot_export_excel.png" width="100%"/></div>

  <h3>How do I use ObjectFinder with my image?</h3>
  
The semi-automated object recognition process starts with creating a folder structure for your experiment with a base directory called after your experiment. Let's assume your experiment folder's name is "MyExperiment".

<div style="text-align:left"> 
<ol>
  <li>Install ObjectFinder in matlab's "App" tab by clicking "</li>
  <li>Start ObjectFinder from your MATLAB® Apps list.</li>
  <div style="text-align:center"><img src ="https://lucadellasantina.github.io/ObjectFinder/Screenshot_MatlabApps.png" width="100%"/></div>  
  <li>Create a subfolder called "MyExperiment/I" where you will place all your original image stacks as 3D .tif files (one file per channel).</li>  
  <li>Click the folder icon to select your experiment folder "MyExperiment"</li>
  <li>Click "Load Images", the available images will be displayed as x-y projection and you will be asked to 6ell ObjectFinder which image contains the structures to recognize. Optionally, you can also specify which image contains a binary mask to limit the search.</li>
  <li>Click "Search Objects" to start the automatic search of objects. Tip: enable the local cluster of cores in MATLAB® (bottom-left icon in your matlab main screen) to go at maximum speed taking full advantage of ObjectFinder's multithreaded search.</li>
  <li>Click "Filter Objects" to remove candidate objects that are too small (only one plane on Z) and touching the optional mask's border</li>
  <li>If you have Bitplane Imaris® 7 installed, you can click on "Inspect 3D" in order to visually inspect and refine detected objects in three dimentions.</li>
 <li>Click "Calc. Density" to finish the detection process and calculate information about object density in the volume.</li>


<div style="text-align:left"> <h3>System Requirements</h3>

Software:
<ul style="list-style-type:none">
  <li>MATLAB R2016b</li>
  <li>Image Processing Toolbox</li>
  <li>Parallel Computing Toolbox</li>
  <li>BitPlane Imaris® 7 (optional)</li>
</ul>

Hardware (recommended):
<ul style="list-style-type:none">
  <li>Processor (CPU): Intel Xeon >2GHz</li>
  <li>System Memory (RAM): 32Gb</li>
  <li>Video Card (GPU): NVidia Quadro with 4Gb VRAM</li>
</ul>

This computer configuration will allow you to process a confocal microscope's image stack of typical size (2048x2048x150 voxels) in about 10 minutes.

<div style="text-align:left"> <h3>Credits</h3>

ObjectFinder is developed and maintained by Luca Della Santina at the University of California, San Francisco. It builds on ideas initially developed in the <a href="http://wonglab.biostr.washington.edu">Wong Lab</a> at the University of Washington in Seattle.