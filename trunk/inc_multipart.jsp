<%@ page 

import="java.io.IOException"
import="java.io.File"
import="java.io.InputStream"
import="java.io.OutputStream"
import="java.io.BufferedOutputStream"
import="java.io.FileOutputStream"
import="java.util.Enumeration"
import="java.util.Vector"
import="javax.servlet.jsp.JspWriter"
import="javax.servlet.ServletInputStream"

%><%

	///////////////////////////////////////////////////////////////////////////////////
	//
	// inc_multipart.jsp: version 1.0
	//
	//	class MultiPart - a generic multipart/form-data parser for JSP
	//
	//	Project: https://code.google.com/p/jsp-multipart
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

	class MultiPart {
		public boolean EOF = false;					// End of Post
		private boolean EOP = true;					// End of PART
		public String charset = "utf-8";
		public String encoding = "ISO-8859-1";
		public String contentType = null;
		protected HttpServletRequest request = null;;
		protected JspWriter out;
		private ServletInputStream in = null;
		private String boundary = null;
		private String preamble = null;
		public MultiPart(HttpServletRequest request, JspWriter out) throws IOException {
			this.request = request;
			this.out = out;
 			this.in = request.getInputStream();
			this.contentType = request.getContentType();
			int type = contentType.indexOf("multipart/form-data");
			if (type >= 0) {
				_parseContentType();
				_initInput();
			} else {
				throw new IOException("content type not multipart/form-data");
			}
		}
		private void DEBUG(String msg) throws IOException {
			// out.println(msg);
		}
		private byte [] linebuf = new byte [2048];
		private String readLine() throws IOException {
			StringBuffer line = new StringBuffer();
			int l; do {
				l = in.readLine(linebuf, 0, linebuf.length);
				if (l > 0) {
					line.append(new String(linebuf, 0, l, this.encoding));
				}
			} while (l == linebuf.length);
			if (line.length() == 0) return null;
			String result = line.toString();
			if (null == result) return null;
			if (result.endsWith("\n")) result = result.substring(0,result.length()-1);
			if (result.endsWith("\r")) result = result.substring(0,result.length()-1);
			return result;
		}
		private void _initInput() throws IOException {
			// Find first boundary
			String line = readLine();
			while (null != line) {
				if (line.startsWith(this.boundary)) {
					DEBUG("First Boundary: " + line);
					return;
				}
				else {
					if (null != preamble) preamble += "\r\n" + preamble;
					else preamble = line;
				}
				line = readLine();
			}
		}
		private void _parseContentType() throws IOException {
			try { DEBUG(this.contentType); } catch(IOException e) {};
			String [] parts = this.contentType.split(";[ ]*");
			this.contentType = parts[0];
			for (int i = 1; i < parts.length; i++) {
				DEBUG(parts[i]);
				if (parts[i].startsWith("charset=")) {
					this.charset = parts[i].substring(8,parts[i].length());
					// this.encoding = this.charset;
					DEBUG(this.charset);
				}
				else if (parts[i].startsWith("boundary=")) {
					this.boundary = "--" + parts[i].substring(9,parts[i].length());
					DEBUG(this.boundary);
				}
			}
			if (null == this.boundary) throw new IOException("Missing boundary argument in content type");
		}

		private String [] getPartHeaders() throws IOException {
			DEBUG("read headers");
			Vector headers = new Vector();
			String line = readLine();
			while (null != line) {
				DEBUG("["+line+"]");
				if (line.length() == 0) { // end of headers
					DEBUG("end of headers");
					this.EOP = false;
					break;
				}
				headers.addElement(line);
				line = readLine();
			}
			if (headers.size() == 0) return null;
			String [] result = new String[headers.size()];
			headers.toArray(result);
			return result;
		}

		// Read ahead buffer
		private byte [] buf = null;

		// Read byte but as part of a small window looking for the boundary
		private int _readByte() throws IOException {
			if (null == buf) {
				buf = new byte[boundary.length()+2];
				int len = in.read(buf,0,buf.length);
				if (len != buf.length) throw new IOException("Premature EOS reading initial part data");
			} else {
				// TODO: Replace with round robin buffer (need to track insertion point)
				System.arraycopy(buf, 1, buf, 0, buf.length-1);
				int len = in.read(buf,buf.length-1,1);
				if (len != 1) throw new IOException("Premature EOS reading part data");
			}

			// Does our buffer == our boundary?
			int i;
			if (buf[0] == 13 && buf[1] == 10) {
				for (i = 0; i < boundary.length(); i++) {
					if (buf[2+i] != boundary.charAt(i)) {
						break;
					}
				}
				if (i == boundary.length()) {
					DEBUG("boundary: [" + (new String(buf)) + "]");
					String line = readLine();		// the \r\n or --\r\n at EOF
					if (null != line && line.startsWith("--")) {
						DEBUG("Signal EOF");
						this.EOF = true;
					}
					buf = null;
					return -1;		// End of part
				}
			}

			// Return the next byte
			return buf[0] & 0xFF;
		}

		private int readPartData(byte[]buf,int off, int l) throws IOException {
			if (this.EOP) return 0;					// Stop reading if hit end of part
			int w = 0;
			while (l>0) {
				int b = _readByte();
				if (b < 0) {
					DEBUG("*end of part*");
					this.EOP = true;				// Signal at end of part
					return w;
				}
				buf[off++] = (byte) b;
				w++;
				l--;
			}
			return w;
		}

		public void process() throws IOException {

			didStartParsingParts(preamble);
			preamble = null;

			String [] headers = getPartHeaders();
			while (null != headers) {

				String partContentType = null;
				String partName = null;
				String partFileName = null;

				// Parse part headers.
				for (int i = 0; i < headers.length; i++) {
					if (headers[i].toLowerCase().startsWith("content-disposition:")) {
						String disposition = headers[i].split(":[ ]*")[1];
						String [] opts = disposition.split(";[ ]");
						for (int o = 0; o < opts.length; o++) {
							if (opts[o].toLowerCase().startsWith("form-data")) {
								// it is form data
							}
							else if (opts[o].toLowerCase().startsWith("name=\"")) {
								partName = opts[o].substring(6,opts[o].length()-1);
							}
							else if (opts[o].toLowerCase().startsWith("filename=\"")) {
								partFileName = opts[o].substring(10,opts[o].length()-1);
							}
						}
					}
					else if (headers[i].toLowerCase().startsWith("content-type:")) {
						partContentType = headers[i].substring(14,headers[i].length());
					}
				}

				// Call overridable method to parse headers
				didStartParsingPart(headers, partContentType, partName, partFileName);

				try {
					// Read part data
					byte [] buff = new byte [1024];
					int l;
					int tot = 0;
					while ((l = readPartData(buff,0,buff.length)) > 0) {
						// Pass chunk of data to part data
						didReadPartData(buff, l);
						tot += l;
					}
					DEBUG("data len " + tot);
				} catch (IOException e) {
					DEBUG("Exception " + e);
				}

				// Allow part cleanup
				didFinishParsingPart();

				// Check for EOF
				if (this.EOF) {
					DEBUG("HIT EOF");
					break;
				}

				// Read next parts headers
				headers = getPartHeaders();
			}

			didFinishParsingParts();
		}

		private File folder = new File("/tmp");
		private File file = null;
		private BufferedOutputStream fileOut = null;

		// Interface
		// Simple open, write, close interface.  
		// Default implementation will write data to disk.
		public void openFile(String fileName) throws IOException {
			file = new File(folder, fileName);
			DEBUG(file.getPath());
			if (!file.isDirectory()) {
				if (file.exists()) file.delete();
				fileOut = new BufferedOutputStream(new FileOutputStream(file));
			} else {
				throw new IOException("File already exists as a directory");
			}
		}
		public void writeFile(byte[] data, int len) throws IOException {
			fileOut.write(data, 0, len);
		}
		public void closeFile() throws IOException {
			fileOut.close();
		}

		// Interface
		// provides access to more detailed information about the parts
		// default implementation uses simple interface to write data to disk
		public void didStartParsingParts(String preamble) throws IOException {
		}
		public void didStartParsingPart(String[] headers, String contentType, String name, String fileName) throws IOException {
			if (null != fileName && fileName.length() > 0) {
				openFile(fileName);
			}
		}
		public void didReadPartData(byte[] data, int len) throws IOException {
			if (null != fileOut) {
				writeFile(data,len);
			}
		}
		public void didFinishParsingPart() throws IOException {
			if (null != fileOut) {
				closeFile();
			}
			fileOut = null;
			file = null;
		}
		public void didFinishParsingParts() throws IOException {
		}
	};
%>
