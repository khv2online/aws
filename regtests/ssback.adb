------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                            Copyright (C) 2003                            --
--                                ACT-Europe                                --
--                                                                          --
--  Authors: Dmitriy Anisimkov - Pascal Obry                                --
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

--  $Id$

with Ada.Streams;
with Ada.Text_IO;

with AWS.Client;
with AWS.Messages;
with AWS.MIME;
with AWS.Net.Buffered;
with AWS.Response;
with AWS.Server;
with AWS.Status;
with AWS.Utils;

procedure SSBack is

   use Ada;
   use AWS;

   Port : Positive := 4469;

   WS : Server.HTTP;

   Wait_Other_Call : constant String := "/wait-for-other-call";

   Store_Socket     : Net.Socket_Type'Class := Net.Socket (True);
   Store_Keep_Alive : Boolean;

   function CB (Request : in Status.Data) return Response.Data;

   task Wait_Call is
      entry Start;
      entry Next (Keep_Alive : Boolean);
      entry Stop;
      entry Stopped;
   end Wait_Call;

   task IO is
      entry Put_Line (Str : in String);
      entry Put_Line_1 (Str : in String);
      entry Put_Line_2 (Str : in String);
      entry Stop;
   end IO;

   -----------------
   -- Wait_Socket --
   -----------------

   protected Wait_Socket is
      entry Wait;
      procedure Set;
   private
      Placed : Boolean := False;
   end Wait_Socket;

   --------
   -- CB --
   --------

   function CB (Request : in Status.Data) return Response.Data is
      URI  : constant String := Status.URI (Request);
   begin
      if URI = Wait_Other_Call then
         Store_Socket     := Status.Socket (Request);
         Store_Keep_Alive := Status.Keep_Alive (Request);

         Wait_Socket.Set;

         return Response.Socket_Taken;
      else
         Net.Buffered.Put_Line
           (Store_Socket, Messages.Status_Line (Messages.S200));

         if Store_Keep_Alive then
            Net.Buffered.Put_Line
              (Store_Socket, Messages.Connection ("Keep-Alive"));
         else
            Net.Buffered.Put_Line
              (Store_Socket, Messages.Connection ("Close"));
         end if;

         declare
            Data : constant Ada.Streams.Stream_Element_Array
              := Status.Binary_Data (Request);
         begin
            Net.Buffered.Put_Line
              (Store_Socket, Messages.Content_Length (Data'Length));

            Net.Buffered.New_Line (Store_Socket);

            Net.Buffered.Write (Store_Socket, Data);
         end;

         Net.Buffered.Flush (Store_Socket);

         if Store_Keep_Alive then
            Server.Give_Back_Socket (Server.Get_Current.all, Store_Socket);

            return Response.Build (MIME.Text_Plain, "was keep-alive.");
         else
            Net.Shutdown (Store_Socket);
            Net.Free     (Store_Socket);

            return Response.Build (MIME.Text_Plain, "was closed.");
         end if;
      end if;
   end CB;

   task body IO is

      procedure Write_Line (Str : in String) is
      begin
         Ada.Text_Io.Put_Line (Str);
         Ada.Text_IO.Flush;
      end Write_Line;

   begin
      loop
         select
            accept Put_Line_1 (Str : in String) do
               Write_Line (Str);
            end Put_Line_1;

            accept Put_Line_2 (Str : in String) do
               Write_Line (Str);
            end Put_Line_2;

         or
            accept Put_Line (Str : in String) do
               Write_Line (Str);
            end Put_Line;

         or
            accept Stop;
            exit;
         end select;
      end loop;
   end IO;

   task body Wait_Call is
      R          : Response.Data;
      Connect    : Client.HTTP_Connection;
      Keep_Alive : Boolean;
   begin
      accept Start;

      Client.Create (Connect, "https://localhost:" & Utils.Image (Port));

      loop
         select
            accept Next (Keep_Alive : Boolean) do
               Wait_Call.Keep_Alive := Next.Keep_Alive;
            end Next;
         or
            accept Stop;
            exit;
         end select;

         if Keep_Alive then
            Client.Get (Connect, R, Wait_Other_Call);
         else
            R := Client.Get
              ("https://localhost:" & Utils.Image (Port) & Wait_Other_Call);
         end if;
         IO.Put_Line_1 (Response.Message_Body (R));
      end loop;

      Client.Close (Connect);

      accept Stopped;
   exception
      when others =>
         IO.Put_Line ("Wait_Call error!");
   end Wait_Call;

   -----------------
   -- Wait_Socket --
   -----------------

   protected body Wait_Socket is

      entry Wait when Placed is
      begin
         Placed := False;
      end Wait;

      procedure Set is
      begin
         Placed := True;
      end Set;

   end Wait_Socket;

begin
   loop
      begin
         Server.Start
           (WS, "file", CB'Unrestricted_Access,
            Port => SSback.Port, Max_Connection => 5, Security => True);
         exit;
      exception
         when Net.Socket_Error =>
            Port := Port + 1;
      end;
   end loop;

   IO.Put_Line ("started");

   Wait_Call.Start;

   declare
      R : Response.Data;
   begin
      for J in 1 .. 10 loop
         Wait_Call.Next (J rem 2 = 0);

         Wait_Socket.Wait;

         R := Client.Post
                ("https://localhost:" & Utils.Image (Port),
                 "Data for transfer from one client to another "
                  & Integer'Image (J) & '.');
         IO.Put_Line_2 (Response.Message_Body (R));
      end loop;
   end;

   Wait_Call.Stop;

   IO.Put_Line ("shutdown...");

   IO.Stop;
   Wait_Call.Stopped;

   delay 1.0;

   Server.Shutdown (WS);
end SSBack;
