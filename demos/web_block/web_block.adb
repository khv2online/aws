------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                       Copyright (C) 2010, AdaCore                        --
--                                                                          --
--  This library is free software; you can redistribute it and/or modify    --
--  it under the terms of the GNU General Public License as published by    --
--  the Free Software Foundation; either version 2 of the License, or (at   --
--  your option) any later version.                                         --
--                                                                          --
--  This library is distributed in the hope that it will be useful, but     --
--  WITHOUT ANY WARRANTY; without even the implied warranty of              --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       --
--  General Public License for more details.                                --
--                                                                          --
--  You should have received a copy of the GNU General Public License       --
--  along with this library; if not, write to the Free Software Foundation, --
--  Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.          --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

with Ada.Text_IO;

with AWS.Server;
with AWS.Services.Web_Block.Registry;

with Web_Callbacks;

procedure Web_Block is

   use Ada;
   use AWS;
   use AWS.Services;

   HTTP : AWS.Server.HTTP;

begin
   Services.Web_Block.Registry.Register
     ("/", "page.thtml", null);
   Services.Web_Block.Registry.Register
     ("COUNTER", "counter.thtml",
      Web_Callbacks.Counter'Access, Context_Required => True);

   Server.Start (HTTP, "web_block", Web_Callbacks.Main'Access);

   Text_IO.Put_Line ("Press Q to terminate.");

   Server.Wait (Server.Q_Key_Pressed);

   Server.Shutdown (HTTP);
end Web_Block;
