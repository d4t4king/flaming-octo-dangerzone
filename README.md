<h1>Flaming-octo-dangerzone</h1>
<p>This is rapidly becoming more than just vtupload.rb, and is turning into a suite of tools (currently) intended to test End Point Protection software. Each script should get its own entry. </p>

<h2>malftp.rb</h2>
<p>Upload or download malware downloaded by maltrieve (link TBD) from/to the ftp server.</p>

<h3>Changes:</h3>

<h3>TODO:</h3>

<hr />

<h2>vtupload.rb</h2>
<p>This is a quick project to upload downloaded malware (from maltrieve) to virustotal.com, for identification.</p>

<p>maltrieve (add link later) downloads malware from various sources for security researchers and analysts.  Yet, the tool
saves the files as the md5 checksum for the name.  This makes it difficult to compare to detection sources.</p>

<h3>Changes:</h3>
<ul>
	<li>10/15/2014 - Provides minimal output/feedback when uploading in CSV mode</li>
	<li>10/16/2014 - Enable hash lookups (faster, lighter) [--skip] </li>
	<li>10/16/2014 - Check file size and skip files greater than ~15MB</li>
</ul>
<h3>TODO:</h3>
<ul>
	<li>Allow --csv flag to accept alternative file name.</li>
	<li>Allow alternate filename/location for api.key file.</li>
</ul>
