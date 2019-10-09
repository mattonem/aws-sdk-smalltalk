Extension { #name : #Lambda }

{ #category : #'*AWS-Lambda-Runtime-Build' }
Lambda class >> bootstrap: className [
	| w |
	w := WriteStream on: (String new: 100).
	w
		<< '#!/bin/sh';
		lf;
		<< './pharo Pharo.image --no-default-preferences eval ';
		<< className;
		<< ' start';
		lf.
	^ w contents
]

{ #category : #'*AWS-Lambda-Runtime-Build' }
Lambda class >> build [
	| workingDir |
	workingDir := self createWorkingDir.
	self zeroConfPharoInto: workingDir.
	OSSUnixSubprocess new
		shellCommand:
			'./pharo Pharo.image metacello install github://mattonem/Phlog:master BaselineOfPhlog';
		workingDirectory: workingDir absolutePath fullName;
		runAndWait.
	workingDir / 'bootstrap'
		writeStreamDo: [ :w | w << (self bootstrap: 'Phlog') ].
	OSSUnixSubprocess new
		shellCommand:
			'./pharo Pharo.image metacello install github://mattonem/Phlog:master BaselineOfPhlog';
		workingDirectory: workingDir absolutePath fullName;
		runAndWait.
	OSSUnixSubprocess new
		shellCommand:
			'zip -r function.zip *.image *.changes *.sources pharo pharo-vm bootstrap';
		workingDirectory: workingDir absolutePath fullName;
		runAndWait
]

{ #category : #'*AWS-Lambda-Runtime-Build' }
Lambda class >> buildRepo: url baseline: baseline group: groupToLoad lambdaClass: lambda [
	| workingDir |
	workingDir := self createWorkingDir.
	self zeroConfPharoInto: workingDir.
	self
		installProject: baseline
		group: groupToLoad
		from: url
		workingDir: workingDir.
	self createBootstrapInto: workingDir lambda: lambda.
	OSSUnixSubprocess new
		shellCommand:
			'zip -r function.zip *.image *.changes *.sources pharo pharo-vm bootstrap';
		workingDirectory: workingDir absolutePath fullName;
		runAndWait.
	^ workingDir
]

{ #category : #'*AWS-Lambda-Runtime-Build' }
Lambda class >> buildRepo: url baseline: baseline lambdaClass: lambda [
	| workingDir |
	workingDir := self createWorkingDir.
	self zeroConfPharoInto: workingDir.
	self installProject: baseline from: url workingDir: workingDir.
	self createBootstrapInto: workingDir lambda: lambda.
	OSSUnixSubprocess new
		shellCommand:
			'zip -r function.zip *.image *.changes *.sources pharo pharo-vm bootstrap';
		workingDirectory: workingDir absolutePath fullName;
		runAndWait
]

{ #category : #'*AWS-Lambda-Runtime-Build' }
Lambda class >> cleanBuilds [
	(FileSystem workingDirectory / 'build') exists
		ifTrue: [ (FileSystem workingDirectory / 'build') deleteAll ]
]

{ #category : #'*AWS-Lambda-Runtime-Build' }
Lambda class >> createBootstrapInto: workingDir lambda: lambda [
	workingDir / 'bootstrap'
		writeStreamDo: [ :w | 
			w << (self bootstrap: lambda).
			w close ].
	OSSUnixSubprocess new
		shellCommand: 'chmod +x bootstrap';
		workingDirectory: workingDir absolutePath fullName;
		runAndWait.
	workingDir / 'bootstrap'
]

{ #category : #'*AWS-Lambda-Runtime-Build' }
Lambda class >> createWorkingDir [
	| workingDir |
	workingDir := FileSystem workingDirectory / 'build' / UUID new asString.
	workingDir exists
		ifTrue: [ workingDir deleteAll ].
	workingDir ensureCreateDirectory.
	^ workingDir
]

{ #category : #'*AWS-Lambda-Runtime-Build' }
Lambda class >> deployFunction: functionName fromDirectory: aWorkingDirectory [
	aWorkingDirectory / 'function.zip'.
		OSSUnixSubprocess new
		shellCommand: 'aws lambda update-function-code --function-name ', functionName, ' --zip-file fileb://function.zip';
		workingDirectory: aWorkingDirectory absolutePath fullName;
		runAndWait
]

{ #category : #'*AWS-Lambda-Runtime-Build' }
Lambda class >> installProject: baseline from: url workingDir: workingDir [
	OSSUnixSubprocess new
		shellCommand: './pharo Pharo.image metacello install ' , url , ' ' , baseline;
		workingDirectory: workingDir absolutePath fullName;
		runAndWait
]

{ #category : #'*AWS-Lambda-Runtime-Build' }
Lambda class >> installProject: baseline group: groupToLoad from: url workingDir: workingDir [
	OSSUnixSubprocess new
		shellCommand: './pharo Pharo.image metacello install ' , url , ' ' , baseline, ' --groups=', groupToLoad;
		workingDirectory: workingDir absolutePath fullName;
		runAndWait
]

{ #category : #'*AWS-Lambda-Runtime-Build' }
Lambda class >> zeroConfPharoInto: workingDir [
	OSSUnixSubprocess new
		shellCommand: 'curl https://get.pharo.org/64/70+vm | bash';
		workingDirectory: workingDir absolutePath fullName;
		runAndWait
]
