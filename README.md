<h1>vtupload.rb</h1>

<p>This is a quick project to upload downloaded malware (from maltrieve) to virustotal.com, for identification.</p>

<p>maltrieve (add link later) downloads malware from various sources for security researchers and analysts.  Yet, the tool
saves the files as the md5 checksum for the name.  This makes it difficult to compare to detection sources.</p>

<h2>TODO:</h2>
<ul>
	<li>Allow --csv flag to accept alternative file name.</li>
	<li>Allow alternate filename/location for api.key file.</li>
	<li>Provide some output when creating CSV report.</li>
</ul>
