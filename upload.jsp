<%@ page 

import="java.io.IOException"
import="javax.servlet.jsp.JspWriter"

%><%

	///////////////////////////////////////////////////////////////////////////////////
	//
	// upload.jsp
	//
	//	class Upload - Example usage of jsp-multipart to upload files to disk
	//
	//  Project: https://code.google.com/p/jsp-multipart
	//	Author: Austin.France@redskyit.com
	//
	//	Copyright (c) 2011, RedSky IT (http://www.redskyit.com)
	//	All rights reserved.
	//
	//	Redistribution and use in source and binary forms, with or without
	//	modification, are permitted provided that the following conditions are met:
	//
	//		* Redistributions of source code must retain the above copyright
	//		notice, this list of conditions and the following disclaimer.
	//
	//		* Redistributions in binary form must reproduce the above copyright
	//		notice, this list of conditions and the following disclaimer in the
	//		documentation and/or other materials provided with the distribution.
	//
	//		* Neither the name of the <organization> nor the
	//		names of its contributors may be used to endorse or promote products
	//		derived from this software without specific prior written permission.
	//
	//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
	//	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
	//	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
	//	DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
	//	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
	//	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
	//	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
	//	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
	//	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	//	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
	//
	///////////////////////////////////////////////////////////////////////////////////

	response.setContentType("text/xml");
	out.println("<"+"?xml version=\"1.0\"?"+">");

	%><%@include file="inc_multipart.jsp"%><%

	//
	// class Upload extends MultiPart and uploads file data from a multipart/form-data 
	// POST method and saves the files to disk.
	//

	class Upload extends MultiPart {

		private long tot = 0;

		public Upload(HttpServletRequest r, JspWriter o) throws IOException {
			super(r,o);
		}

		public void didStartParsingParts(String preamble) throws IOException {
			super.folder = new File("/tmp");		// set where uploads should be saved
			out.println("<Upload>");
		}

		public void openFile(String fileName) throws IOException {
			super.openFile(fileName);
			tot = 0;
			out.println("<Part>");
			out.println("<FileName>" + fileName + "</FileName>");
		}

		public void writeFile(byte[] data, int len) throws IOException {
			super.writeFile(data,len);
			tot += len;
		}

		public void closeFile() throws IOException {
			super.closeFile();
			out.println("<Size>"+tot+"</Size>");
			out.println("</Part>");
		}

		public void didFinishParsingParts() throws IOException {
			out.println("</Upload>");
		}
	}

	// Create our upload object
	Upload upload = new Upload(request, out);

	// and process the form data
	upload.process();

%>
