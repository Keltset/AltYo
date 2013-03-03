/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

using Gtk;
using Cairo;

public class point_a {
	public unowned Gtk.ActionGroup ag;
	public StringBuilder sb;
	public point_a(Gtk.ActionGroup ag) {
		this.ag=ag;
		this.sb=new StringBuilder();
	}
}

public enum WStates{
	VISIBLE,
	HIDDEN
	}

public enum TASKS{
	TERMINALS,
	QLIST
	}

public enum TAB_SORT_ORDER{
	NONE,
	HOSTNAME
	}

public delegate void MyCallBack(Gtk.Action a);

public class VTMainWindow : Window{
	public OffscreenWindow pixwin;
	public AYObject ayobject;
	
	public bool maximized=false;
	private bool update_maximized_size=false;
	public bool animation_enabled = true;
	public int animation_speed=25;
	public int pull_steps=20;
	public bool pull_animation_active = false;
	public bool pull_active = false;
	public WStates current_state {get;set; default = WStates.VISIBLE;}
	public unowned MySettings conf {get;set; default = null;}
	public bool keep_above=true;

	public PanelHotkey hotkey;
	public bool mouse_follow=false;
	private unowned Widget prev_focus=null;
	
	private int pull_step = 0;
	public int orig_x = 0;
	public int orig_y = 0;
	private int pull_w = 0;
	private int pull_h = 0;
	private int orig_h_tasks_notebook=0;
	private int orig_w_tasks_notebook=0;
	private int orig_h_main_vbox=0;
	private int orig_w_main_vbox=0;
	public int position = 1;
	public bool config_maximized=false;
	public bool pull_maximized=false;
	public bool temporary_maximized=false;
	public bool allow_close=false;

	
	
	public VTMainWindow(WindowType type) {
		Object(type:type);
		}

	construct {
		this.title = "AltYo";
		//this.border_width = 0;
		this.skip_taskbar_hint = true;
		this.urgency_hint = true;
		this.set_decorated (false);
		this.resizable = true;//we need resize!
		this.set_has_resize_grip(false);//but hide grip
		//this.set_focus_on_map (true);
		//this.set_accept_focus (true);
		this.set_keep_above(true);
		this.stick ();
		this.pixwin = new OffscreenWindow ();
		this.pixwin.name="OffscreenWindow";
		this.pixwin.show();
		//this.set_app_paintable(true);
		//this.set_double_buffered(false);

//~ 		Gdk.RGBA c = Gdk.RGBA();
//~ 		c.parse("#000000");//black todo: make same color as vte
//~ 		c.alpha = 0.0;//transparency

		this.set_visual (this.screen.get_rgba_visual ());//transparancy
		this.set_app_paintable(true);//do not draw backgroud
//~ 		this.override_background_color(StateFlags.NORMAL, c);
		//this.pixwin.set_visual (this.screen.get_rgba_visual ());//transparancy
		//this.pixwin.set_app_paintable(true);//do not draw backgroud
	}

	public void CreateVTWindow(MySettings conf) {
		this.conf=conf;
		this.keep_above=conf.get_boolean("keep_above_at_startup",this.keep_above);
		if(!this.keep_above){
			this.skip_taskbar_hint = false;
			this.set_keep_above(false);
		}


		Image img = new Image.from_resource ("/org/gnome/altyo/altyo.svg");
		this.set_icon(img.pixbuf);

		this.keep_above=conf.get_boolean("keep_above_at_startup",this.keep_above);
		if(!this.keep_above){
			this.skip_taskbar_hint = false;
			this.set_keep_above(false);
		}

		this.hotkey = new PanelHotkey ();
		this.reconfigure();//window
	
		this.ayobject= new AYObject(this,conf);

		this.add(this.ayobject.main_vbox);
		

		conf.get_boolean("prevent_close_window",true);//just read value
		this.delete_event.connect (()=>{
			var b=conf.get_boolean("prevent_close_window",true);
			if(b==true && this.allow_close==false){
				this.ayobject.ShowQuitDialog();
				return true;//prevent close
			}
			return false;//default is allow
			});
		
		this.destroy.connect (()=>{
			this.ayobject.save_configuration();
			this.conf.save();
			Gtk.main_quit();
			});
			
		this.conf.on_load.connect(()=>{
			this.reconfigure();
			if(this.current_state==WStates.VISIBLE){
				this.configure_position();
				this.update_position_size();
				this.update_events();
			}
			});
		this.configure_position();
		this.update_position_size();
	}
	
	public bool on_pull_down(){

			this.pull_step++;
			if(this.pull_step<this.pull_steps){
				this.resize (this.pull_w,(this.pull_h/this.pull_steps)*this.pull_step);
				this.update_events();
				return true;//continue animation
			}else{
				this.update_events();
				this.pull_active=false;
				this.current_state=WStates.VISIBLE;
				if(this.pull_step==this.pull_steps){
					debug("on_pull_down last step");
					/* update hints, so first pull up ,after maximize, will be smooth
					 * this size will be after unmaximize (pull_up call unmaximize)
					 * */
					if(this.pull_maximized){
						this.maximize();
					}else{
						this.set_default_size(this.pull_w,pull_h);
						this.resize (this.pull_w,pull_h);
					}
					this.update_events();
					return true;//continue animation
				}
							
				var ch=this.pixwin.get_child();//.reparent(this);//reparent from offscreen window
				this.pixwin.remove(ch);
				this.add(ch);
				this.pull_animation_active=false;
				
				this.update_position_size();
				this.window_set_active();
				this.update_events();
				
//~				if(this.pull_maximized){
//~					this.maximize();
//~					this.update_events();
//~				}
//~
//~				var ch=this.pixwin.get_child();//.reparent(this);//reparent from offscreen window
//~				this.pixwin.remove(ch);
//~				this.add(ch);
//~				
//~				this.update_position_size();
//~				this.window_set_active();
//~				this.update_events();

				return false;
			}
	}

	public void pull_down(){
		if(this.pull_animation_active)
			return;		
		if(!this.animation_enabled){
			this.configure_position();
			this.show();
			this.move (this.orig_x ,this.orig_y);
			this.current_state=WStates.VISIBLE;
			this.update_events();
			this.update_position_size();
			this.update_events();
			this.window_set_active();
			this.update_events();
			return;
		}
		this.pull_animation_active=true;
		if(!this.pull_maximized)
			this.configure_position();
		this.show();
		this.realize();
		this.update_events();
		this.resize (this.pull_w,2);//start height
		this.move (this.orig_x,this.orig_y);
		this.update_events();
		if (this.pull_w != 0 && this.pull_h != 0)
			this.pull_step=0;
		else
			this.pull_step=this.pull_steps;//skip animation
		GLib.Timeout.add(this.animation_speed,this.on_pull_down);
	}

	public bool on_pull_up(){
			this.pull_step++;
			this.resize (this.pull_w,(this.pull_h-(this.pull_h/this.pull_steps)*this.pull_step)+1);
//~			this.queue_draw();
			this.update_events();
			if(this.pull_step<this.pull_steps)
				return true;//continue animation
			else{
				//look at source of gtk_window_reshow_with_initial_size (GtkWindow *window)
				var gem=new Gdk.Geometry();
				gem.base_height=0;//this.pull_h;
				gem.base_width=this.pull_w;
				gem.height_inc=0;
				gem.max_aspect=0;
				gem.max_height=0;
				gem.max_width=0;
				gem.min_aspect=0;
				gem.min_height=1;//allow min height
				gem.min_width=this.pull_w;
				gem.width_inc=0;
				gem.win_gravity=Gdk.Gravity.NORTH_WEST;
				this.set_geometry_hints(null,gem,Gdk.WindowHints.MIN_SIZE|Gdk.WindowHints.BASE_SIZE);				

				this.hide();
				this.unrealize();//important!
				this.current_state=WStates.HIDDEN;
				this.pull_animation_active=false;
				return false;
			}
	}

	public void pull_up(){
		if(this.pull_animation_active)
			return;		
		this.pull_h=this.get_allocated_height();
		this.pull_w=this.get_allocated_width();
		this.prev_focus=this.get_focus();
		debug("pull_up orig_h=%d orig_w=%d",this.pull_h,this.pull_w);
		this.orig_h_main_vbox = this.ayobject.main_vbox.get_allocated_height();
		this.orig_w_main_vbox = this.ayobject.main_vbox.get_allocated_width();
		this.orig_h_tasks_notebook = this.ayobject.tasks_notebook.get_allocated_height();
		this.orig_w_tasks_notebook = this.ayobject.tasks_notebook.get_allocated_width();
		debug("pull_up orig_h_note=%d orig_w_note=%d",orig_h_main_vbox,orig_w_main_vbox);
		this.pull_maximized=this.maximized;
		if(!this.animation_enabled){
			this.prev_focus=this.get_focus();
			this.hide();
			this.unrealize();//important!
			this.current_state=WStates.HIDDEN;
			return;
		}

		this.pull_active=true;
		this.pull_animation_active=false;
		if(this.pull_w<=0 || this.pull_h<=0)
			return;

		this.pixwin.set_default_size(pull_w,pull_h);//important
		this.pixwin.set_size_request (pull_w,pull_h);//important
		this.pixwin.resize (pull_w,pull_h);//important
		this.update_events();
		debug("reparent to offscreen window");
		//this.get_child().reparent(this.pixwin);//reparent to offscreen window
			var ch=this.get_child();//.reparent(this);//reparent from offscreen window
				this.remove(ch);
				this.pixwin.add(ch);		
		debug("end reparent to offscreen window");
		//correct size after unmaximize
		//just to be shure that terminal will not change size
		
		if(this.maximized){
			this.ayobject.main_vbox.set_size_request(orig_w_main_vbox,orig_h_main_vbox);
			this.update_events();

			/*reset geometry hints, allow min height =1
			 * */
			var gem=new Gdk.Geometry();
			gem.base_height=0;//this.pull_h;
			gem.base_width=this.pull_w;
			gem.height_inc=0;
			gem.max_aspect=0;
			gem.max_height=0;
			gem.max_width=0;
			gem.min_aspect=0;
			gem.min_height=1;//allow min height
			gem.min_width=this.pull_w;
			gem.width_inc=0;
			gem.win_gravity=Gdk.Gravity.NORTH_WEST;
			this.set_geometry_hints(null,gem,Gdk.WindowHints.MIN_SIZE|Gdk.WindowHints.BASE_SIZE);			

			this.unmaximize();
			this.update_events();
		}else{
			this.ayobject.main_vbox.set_size_request(this.orig_w_main_vbox,orig_h_main_vbox);
			this.ayobject.tasks_notebook.set_size_request(orig_w_tasks_notebook,orig_h_tasks_notebook);
			this.update_events();
		}
			
		
		debug("pull_up 0-%d  this.get_allocated_height=%d this.orig_h=%d",this.get_allocated_height()-this.pull_h, this.get_allocated_height(),this.pull_h);
		debug("pull_up orig_h=%d orig_w=%d",this.pull_h,this.pull_w);
		this.pull_step=0;
		this.pull_animation_active=true;
		GLib.Timeout.add(this.animation_speed,this.on_pull_up);
	}

	public void toogle_widnow(){
		if(this.pull_animation_active) return;
			if(this.current_state == WStates.HIDDEN)
					this.pull_down();
				else
					this.pull_up();
	}

	public override bool window_state_event (Gdk.EventWindowState event){
		debug("window_state_event type=%d new_state=%d mask=%d",(int)event.type,(int)event.new_window_state,(int)event.changed_mask);
		 var ret=base.window_state_event(event);
		if(!this.pull_active && !this.pull_animation_active){
				debug("window_state_event !!!!!!!!! this.maximized=%d",(int)this.maximized);
			//ignore maximize event when pull active
			if( (event.changed_mask & Gdk.WindowState.MAXIMIZED)==Gdk.WindowState.MAXIMIZED ){//maximize state change
				if((Gdk.WindowState.MAXIMIZED & event.new_window_state)== Gdk.WindowState.MAXIMIZED){//maximize
					if(!this.maximized){
						this.maximized = true;
						this.configure_position();
						this.update_position_size();
						this.update_maximized_size=true;
					}
					//this.maximized = true;
				}else{//unmaximize
					if(this.maximized){
						this.maximized = false;
						/*reset geometry hints
						 * */
						var gem=new Gdk.Geometry();
						gem.base_height=0;
						gem.base_width=0;
						gem.height_inc=0;
						gem.max_aspect=0;
						gem.max_height=0;
						gem.max_width=0;
						gem.min_aspect=0;
						gem.min_height=1;//allow resize from maximized size
						gem.min_width=1;//allow resize from maximized size
						gem.width_inc=0;
						gem.win_gravity=Gdk.Gravity.NORTH_WEST;
						this.set_geometry_hints(null,gem,Gdk.WindowHints.MIN_SIZE|Gdk.WindowHints.BASE_SIZE);						

						this.configure_position();
						this.update_position_size();
						//this.update_maximized_size=true;
					}			
				}
			}
		}
	return ret;
	//false;//continue
	//base.window_state_event(event);
	}

	public override bool configure_event(Gdk.EventConfigure event){
		debug("configure_event");
		debug("event.type=%d window=%d x=%d y=%d width=%d height=%d",event.type,(int)event.window,event.x,event.y,event.width,event.height);
//~		if(this.pull_animation_active || this.pull_active)//ignore event when pull active
//~			return false;
		var ret=base.configure_event(event);

		if(event.type==13 && this.current_state==WStates.VISIBLE){
			this.orig_x=event.x;
			this.orig_y=event.y;
			if(update_maximized_size){
				/* update hints, so first pull up ,after maximize, will be smooth
				 * this size will be after unmaximize (pull_up call unmaximize)
				 * */
					this.update_maximized_size=false;
					var gem=new Gdk.Geometry();
					gem.base_height=event.height;
					gem.base_width=event.width;
					gem.height_inc=0;
					gem.max_aspect=0;
					gem.max_height=0;
					gem.max_width=0;
					gem.min_aspect=0;
					gem.min_height=event.height;//this size will be after unmaximize
					gem.min_width=event.width;//this size will be after unmaximize
					gem.width_inc=0;
					gem.win_gravity=Gdk.Gravity.NORTH_WEST;
					this.set_geometry_hints(null,gem,Gdk.WindowHints.MIN_SIZE|Gdk.WindowHints.BASE_SIZE);
			}
		}
	return ret;
	}

	public override  bool draw (Cairo.Context cr){
		if(this.pull_animation_active || this.pull_active){
			cr.save();
			//debug("draw 0-%d  this.get_allocated_height=%d this.orig_h=%d",this.get_allocated_height()-this.pull_h, this.get_allocated_height(),this.pull_h);
			cr.set_source_surface(this.pixwin.get_surface(),0,this.get_allocated_height()-this.pull_h);
			cr.paint();
			cr.stroke ();
			cr.restore();
			return false;
		}else{
			return base.draw(cr);
		}
	}


	public void update_events(){
		var window = this.get_window();
			//window.process_updates(true);//force update
			if(window!=null)
				window.enable_synchronized_configure();//force update
		while (Gtk.events_pending ()){
			Gtk.main_iteration ();
			}
		Gdk.flush();

	}

	public void update_position_size(){
				debug ("update_position_size start");
				/*update terminal align policy
				 * */
				this.ayobject.on_maximize(this.maximized);
				/* update position only in unmaximized mode
				 * */
				if(!this.maximized && !this.config_maximized){
						var should_be_h = this.ayobject.terminal_height+this.ayobject.hvbox.get_allocated_height();
						
						if(this.get_allocated_height()>should_be_h+2||
						this.ayobject.terminal_width!=this.get_allocated_width()){
							//this.configure_position();//this needed to update position after unmaximize
							this.ayobject.main_vbox.set_size_request(this.ayobject.terminal_width,0);
							this.ayobject.tasks_notebook.set_size_request(this.ayobject.terminal_width,this.ayobject.terminal_height);
							this.set_default_size(this.ayobject.terminal_width,should_be_h);
							this.resize (this.ayobject.terminal_width,should_be_h);
							this.queue_resize_no_redraw();
							
							//GLib.Timeout.add(10,()=>{debug("Update events");this.update_events(); return false;});
							debug ("update_position_size should_be_h=%d terminal_width=%d",should_be_h,this.ayobject.terminal_width) ;
						}						
						this.move (this.orig_x,this.orig_y);
						this.update_events();
				}else{
					if(this.orig_w_main_vbox!=0 && this.orig_h_main_vbox!=0 &&
						this.orig_w_tasks_notebook!=0 && this.orig_h_tasks_notebook!=0){
					this.ayobject.main_vbox.set_size_request(this.orig_w_main_vbox,this.orig_h_main_vbox);
					this.ayobject.tasks_notebook.set_size_request(this.orig_w_tasks_notebook,this.orig_h_tasks_notebook);
					}
					this.maximize();
				}
	}
	public void reconfigure(){
		debug("reconfigure VTWindow");
		var css_main = new CssProvider ();
		string style_str= ""+
					 "VTToggleButton,VTToggleButton GtkLabel  {font: Mono 10; -GtkWidget-focus-padding: 0px;  -GtkButton-default-border:0px; -GtkButton-default-outside-border:0px; -GtkButton-inner-border:0px; border-width: 0px; -outer-stroke-width: 0px; border-radius: 0px; border-style: solid;  background-image: none; margin:0px; padding:1px 1px 0px 1px; background-color: alpha(#000000,0.0); color: #AAAAAA; transition: 0ms ease-in-out;}"+
					 "VTToggleButton:active{background-color: #00AAAA; color: #000000; transition: 0ms ease-in-out;}"+
					 "VTToggleButton:prelight {background-color: #AAAAAA; color: #000000; transition: 0ms ease-in-out;}"+
					 "#tasks_notebook {border-width: 0px 2px 0px 2px;border-color: #3C3B37;border-style: solid;}"+
					 "#search_hbox :active { border-color: @fg_color; color: #FF0000;}"+
					 "#search_hbox :prelight { background-color: alpha(#000000,0.0); border-color: @fg_color; color: #FF0000;}"+
					 "#search_hbox {border-width: 0px 0px 0px 0px; -outer-stroke-width: 0px; border-radius: 0px 0px 0px 0px; border-style: solid;  background-image: none; margin:0px; padding:0px 0px 1px 0px; background-color: #000000; border-color: @bg_color; color: #00FFAA;}"+
					 "HVBox {border-width: 0px 2px 2px 2px; border-color: #3C3B37;border-style: solid; background-color: #000000;}"+
					 "#OffscreenWindow, VTMainWindow,#HVBox_dnd_window {border-width: 0px; border-style: solid; background-color: alpha(#000000,0.1);}"+
					 "HVBox,#search_hbox{background-color: alpha(#000000,1.0);}"+
					 "";
		css_main.parsing_error.connect((section,error)=>{
			debug("css_main.parsing_error %s",error.message);
			});

		try{
			css_main.load_from_data (this.conf.get_string("program_style",style_str),-1);
			Gtk.StyleContext.add_provider_for_screen(this.get_screen(),css_main,Gtk.STYLE_PROVIDER_PRIORITY_USER);
		}catch (Error e) {
			debug("Theme error! loading default..");
			css_main.load_from_data (style_str,-1);
			Gtk.StyleContext.add_provider_for_screen(this.get_screen(),css_main,Gtk.STYLE_PROVIDER_PRIORITY_USER);
		}
		this.position  = conf.get_integer("position",1,(ref new_val)=>{
			if(new_val>3){new_val=this.position;return true;}
			return false;
			});

		this.animation_enabled=conf.get_boolean("animation_enabled",true);
		this.pull_steps=conf.get_integer("animation_pull_steps",10,(ref new_val)=>{
				if(new_val<1){new_val=10;return true;}
				return false;
			});

		this.hotkey.unbind();
		KeyBinding grave=this.hotkey.bind (this.conf.get_accel_string("main_hotkey","<Alt>grave"));
		if(grave!=null)
			grave.on_trigged.connect(this.toogle_widnow);
		else{
			var new_key = this.conf.get_accel_string("main_hotkey","<Alt>grave");
			do{
				new_key = this.ShowGrabKeyDialog(new_key);
				grave=this.hotkey.bind (new_key);
			}while(grave==null);
			this.conf.set_accel_string("main_hotkey",new_key);
			grave.on_trigged.connect(this.toogle_widnow);
		}

		this.mouse_follow  = conf.get_boolean("follow_the_white_rabbit",false);
	}//reconfigure

	public void configure_position(){
			unowned Gdk.Screen gscreen = this.get_screen ();
			debug("x=%d,y=%d",this.orig_x,this.orig_y);
			int current_monitor;
			if(this.mouse_follow){
				X.Display display = new X.Display();
				X.Event event = X.Event();
				X.Window window = display.default_root_window();

				display.query_pointer(window, out window,
				out event.xbutton.subwindow, out event.xbutton.x_root,
				out event.xbutton.y_root, out event.xbutton.x,
				out event.xbutton.y, out event.xbutton.state);
				current_monitor = gscreen.get_monitor_at_point (event.xbutton.x,event.xbutton.y);
			}else
			    current_monitor = gscreen.get_monitor_at_point (this.orig_x,this.orig_y);

			Gdk.Rectangle rectangle;
			rectangle=gscreen.get_monitor_workarea(current_monitor);


			int w = conf.get_integer("terminal_width",80);//if less 101 then it persentage
			int h = conf.get_integer("terminal_height",50);//if less 101 then it persentage
			if(h==100){//workaround for fullscreen, otherwise tabbutton will be out of screen
				if(!this.config_maximized && !this.maximized){
					this.maximize();
				}
				this.config_maximized=true;
				this.ayobject.terminal_width=(int)rectangle.width;
				this.ayobject.terminal_height=(int)rectangle.height-rectangle.height/3;
			}else{
					
				if(w<101){
					this.ayobject.terminal_width=(int)(((float)rectangle.width/100.0)*(float)w);
				}else{
					this.ayobject.terminal_width=w;
				}

				if(h<101){
					this.ayobject.terminal_height=(int)(((float)rectangle.height/100.0)*(float)h);
				}else{
					this.ayobject.terminal_height=h;
				}

				if(this.config_maximized && this.maximized){
					this.config_maximized=false;
					debug("configure_position unmaximize");
					this.unmaximize();
					this.update_events();
				}else
					this.config_maximized=false;
			}

			if(this.position>3)this.position=1;

			switch(this.position){
				case 0:
					this.orig_x=rectangle.x;
				break;
				case 1:
					this.orig_x=rectangle.x+((rectangle.width/2)-(this.ayobject.terminal_width/2));
				break;
				case 2:
					this.orig_x=rectangle.x+(rectangle.width-this.ayobject.terminal_width);
				break;
			}

			//this.orig_x=rectangle.x;
			this.orig_y=rectangle.y;

			//this.tasks_notebook.set_size_request(this.terminal_width,this.terminal_height);
			//we can't change height , otherwise vte will change
			//this.tasks_notebook.set_size_request(terminal_width,this.terminal_height);
			debug("new x=%d,y=%d",this.orig_x,this.orig_y);
	}//configure_position


		public void window_set_active(){

		if(this.current_state==WStates.VISIBLE){
			if(!this.maximized){
				this.ayobject.tasks_notebook.set_size_request(this.ayobject.terminal_width,this.ayobject.terminal_height);

				if(this.get_allocated_height()>this.ayobject.terminal_height+this.ayobject.hvbox.get_allocated_height ()){
					this.set_default_size (this.ayobject.terminal_width,this.ayobject.terminal_height+this.ayobject.hvbox.get_allocated_height ());
					this.resize (this.ayobject.terminal_width,this.ayobject.terminal_height+this.ayobject.hvbox.get_allocated_height ());
				}
			}
			if(this.keep_above){
				this.skip_taskbar_hint = true;
				this.set_keep_above(true);
				this.stick ();
				//this.show ();//first show then send_net_active_window!
				this.present() ;
			}else{
				this.skip_taskbar_hint = false;
				this.set_keep_above(false);
			}
			this.hotkey.send_net_active_window(this.get_window ());
			if(this.prev_focus!=null)
				this.prev_focus.grab_focus();
			else
				this.ayobject.activate_tab(this.ayobject.active_tab);
		}
	}


	public string ShowGrabKeyDialog(string? prev_bind=null){

			var title="Please select key combination, to show/hide AltYo.";
			if(prev_bind!=null)
				title+="\nprevious key '%s' incorrect or busy".printf(prev_bind);
			var dialog = new MessageDialog (null, (DialogFlags.DESTROY_WITH_PARENT | DialogFlags.MODAL), MessageType.QUESTION, ButtonsType.OK, title);
			var aLabel = new Label("Press any key");
			var dialog_box = ((Gtk.Box)dialog.get_content_area ());
			dialog_box.pack_start(aLabel,false,false,0);
			aLabel.show();
			dialog.response.connect ((response_id) => {
				if(response_id == Gtk.ResponseType.OK){
					dialog.destroy ();
				}else{
					this.window_set_active();
					dialog.destroy ();
				}
			});

			var grab_another_key = new Button.with_label("Grab another key.");
			grab_another_key.clicked.connect(()=>{
				grab_another_key.sensitive=false;
				dialog.set_response_sensitive(Gtk.ResponseType.OK,false);
				});

			((Gtk.ButtonBox)dialog.get_action_area ()).pack_start(grab_another_key,false,false,0);
			grab_another_key.show();
			grab_another_key.sensitive=false;

			dialog.focus_out_event.connect (() => {
				return true; //same bug as discribed in this.focus_out_event
				});

			dialog.set_response_sensitive(Gtk.ResponseType.OK,false);
			dialog.set_transient_for(this);
			dialog.show ();
			//disable close by window manager
			Gdk.Window w = dialog.get_window();
			w.set_functions((Gdk.WMFunction.ALL|Gdk.WMFunction.CLOSE));
			dialog.grab_focus();
			this.hotkey.send_net_active_window(dialog.get_window ());
			string accelerator_name="";

			dialog.key_press_event.connect((widget,event) => {
					unowned Button ok = (Button)dialog.get_widget_for_response(Gtk.ResponseType.OK);
					if(!ok.sensitive)
						if (Gtk.accelerator_valid (event.keyval, event.state))
						/*See GDK_KEY_* in gdk/gdkkeysyms.h (not available in Vala)*/
							if(event.keyval!=0xff1b && /*GDK_KEY_Escape*/
							   event.keyval!=0xff0d && /*GDK_KEY_Return*/
							   event.keyval!=0xff08    /*GDK_KEY_BackSpace*/
							   ){
								event.state &= Gtk.accelerator_get_default_mod_mask();
								accelerator_name = Gtk.accelerator_name (event.keyval, event.state);
								aLabel.label = Gtk.accelerator_get_label  (event.keyval, event.state);
								ok.sensitive=true;
								ok.grab_focus();
								grab_another_key.sensitive=true;
							}
					if(event.keyval!=0xff1b && ok.sensitive)
						return false;
					else
						return true; //true == ignore event
				});//tab_button_press_event
			dialog.run();
			return accelerator_name;
	}
}//class VTMainWindow

/*********************************************************************/
/*********************************************************************/
/*********************************************************************/
/*********************************************************************/
/*********************************************************************/
/*********************************************************************/
/*********************************************************************/

public class AYObject :Object{
	public Gtk.ActionGroup action_group;
	public Gtk.AccelGroup  accel_group;

	public bool save_session = false;

	private int double_hotkey_milliseconds = 0;
	private int double_hotkey = 0;
	private DateTime double_hotkey_last_time = null;

//~ 	public Overlay main_overlay {get;set;}
//~ 	public MyOverlayBox main_overlay {get;set;}
	public VTMainWindow main_window;
	public Notebook terms_notebook {get; set;}
	public Notebook tasks_notebook {get; set;}
	public Notebook overlay_notebook {get; set;}
	public HVBox hvbox {get;set;}
	public Gtk.Box search_hbox  {get;set;}
	public ComboBoxText search_text_combo {get;set;}
	public CheckButton search_wrap_around {get;set;}
	public CheckButton search_match_case {get;set;}
	public int search_history_length = 10;
	public unowned VTToggleButton active_tab {get;set; default = null;}
	public unowned MySettings conf {get;set; default = null;}
	//public Gtk.Window win {get;set; default = null;}

	public Gtk.Box main_vbox  {get;set;}

	public TAB_SORT_ORDER tab_sort_order {get;set; default = TAB_SORT_ORDER.NONE;}


	private List<unowned AYTab> children;
	public int terminal_width {get;set; default = 80;}
	public int terminal_height {get;set; default = 50;}
	private int hvbox_height_old {get;set; default = 0;}
	//public bool maximized {get; set; default = false;}
	//private bool quit_dialog {get; set; default = false;}

	private AYSettings aysettings {get;set; default = null;}
	private bool aysettings_shown=false;

	public AYObject(VTMainWindow _MW ,MySettings _conf) {
		debug("AYObject new");
		this.conf=_conf;
		this.main_window=_MW;

		this.main_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);//new VBox(false,0);
		this.main_vbox.halign=Gtk.Align.FILL;
		this.main_vbox.valign=Gtk.Align.FILL;
		this.main_vbox.expand=false;
		this.main_vbox.name="main_vbox";
		this.main_vbox.show();

		
		this.terms_notebook = new Notebook() ;
//~		this.terms_notebook.halign=Gtk.Align.FILL;
//~		this.terms_notebook.valign=Gtk.Align.START;
		this.terms_notebook.expand=false;

		this.terms_notebook.name="terms_notebook";
		this.terms_notebook.set_show_tabs(false);//HVBox will have tabs ;)

		//this.terms_notebook.set_show_border(false);

		this.tasks_notebook = new Notebook();
//~		this.tasks_notebook.halign=Gtk.Align.FILL;
//~		this.tasks_notebook.valign=Gtk.Align.START;
		this.tasks_notebook.expand=false;
		this.tasks_notebook.name="tasks_notebook";
		this.tasks_notebook.set_show_tabs(false);
		this.tasks_notebook.insert_page(terms_notebook,null,TASKS.TERMINALS);
		this.tasks_notebook.switch_page.connect(on_switch_task);

		this.save_session    = conf.get_boolean("autosave_session",false);

		this.tasks_notebook.set_size_request(terminal_width,this.terminal_height);

		this.hvbox = new HVBox();
		this.hvbox.halign=Gtk.Align.FILL;
		this.hvbox.valign=Gtk.Align.START;
		this.hvbox.expand=false;
		
		this.hvbox.child_reordered.connect(this.move_tab);
		this.hvbox.size_changed.connect(this.hvbox_size_changed);

		this.hvbox.can_focus=false;//vte shoud have focus
		this.hvbox.can_default = false;
		this.hvbox.has_focus = false;

		this.search_hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);//new HBox(false,0);
		this.search_hbox.halign=Gtk.Align.FILL;
		this.search_hbox.valign=Gtk.Align.START;
		this.search_hbox.expand=false;
		this.search_hbox.name="search_hbox";
		this.search_hbox.draw.connect((cr)=>{
			int width = this.search_hbox.get_allocated_width ();
			int height = this.search_hbox.get_allocated_height ();
			var context = this.search_hbox.get_style_context();
			render_background(context,cr, -1, -1,width+2, height+2);
			this.search_hbox.foreach((widget)=>{
				if(widget.parent==this.search_hbox)
					this.search_hbox.propagate_draw(widget,cr);
				});
				return false;
			});
		this.create_search_box();

		//this.main_vbox.pack_start(this.tasks_notebook,true,true,0);//maximum size

		#if HAVE_QLIST
		var qlist = new QList(this.conf);
		qlist.win_parent=this;
		this.tasks_notebook.insert_page(qlist,null,TASKS.QLIST);
		#endif

		/*this.main_overlay = new MyOverlayBox();//Gtk.Overlay();
		this.main_overlay.show();
		this.main_overlay.add(this.tasks_notebook);

		this.overlay_notebook = new Notebook() ;
		this.overlay_notebook.set_show_tabs(false);

		this.main_overlay.add_overlay(this.overlay_notebook);*/

		//this.main_vbox.pack_start(this.main_overlay,true,true,0);//maximum size
		this.main_vbox.pack_start(this.tasks_notebook,true,true,0);//maximum size


		//this.main_vbox.pack_start(notebook,true,true,0);//maximum size
		this.main_vbox.pack_start(this.search_hbox,false,false,0);//minimum size
		this.main_vbox.pack_end(hvbox,false,false,0);//minimum size

		this.reconfigure();
		this.main_vbox.show_all();

		var restore_terminal_session=this.conf.get_string_list("terminal_session",null);
		if(restore_terminal_session != null && restore_terminal_session.length>0){
			foreach(var s in restore_terminal_session){
				if(s!="")
					this.add_tab(s);
				else
					this.add_tab();
			}
		}else
			this.add_tab();

		this.search_hbox.hide();//search hidden by default
		//this.overlay_notebook.hide();//this.overlay_notebook hidden by default
		this.tasks_notebook.set_current_page(TASKS.TERMINALS);//this.overlay_notebook hidden by default


		//this.setup_keyboard_accelerators() ;
		#if HAVE_QLIST
		qlist.setup_keyboard_accelerators();
		#endif

		this.conf.on_load.connect(()=>{
			this.reconfigure();
			});

	}//CreateAYObject


	public void reconfigure(){
		debug("reconfigure AYObject");

		this.terminal_width = conf.get_integer("terminal_width",80,(ref new_val)=>{
			if(new_val<1){new_val=this.terminal_width;return true;}
			return false;
			});
		this.terminal_height = conf.get_integer("terminal_height",50,(ref new_val)=>{
			if(new_val<1){new_val=this.terminal_height;return true;}
			return false;
			});

		this.hvbox.background_only_behind_widgets= !conf.get_boolean("tab_box_have_background",false);

		this.save_session  = conf.get_boolean("autosave_session",false);
		this.double_hotkey_milliseconds=conf.get_integer("double_hotkey_milliseconds",500)*1000;
		string ret = conf.get_string("tab_sort_order","none");
			switch(ret){
				case "none":
					this.tab_sort_order=TAB_SORT_ORDER.NONE;
				break;
				case "hostname":
					this.tab_sort_order=TAB_SORT_ORDER.HOSTNAME;
				break;
				default:
					this.tab_sort_order=TAB_SORT_ORDER.NONE;
					conf.set_string("tab_sort_order","none");
				break;
				}



		this.setup_keyboard_accelerators();
	}

	public VTTerminal add_tab(string? session_command=null,string? session_path=null,OnChildExitCallBack? on_exit=null) {
		VTTerminal vt;
		if(on_exit==null){
			vt = new VTTerminal(this.conf,this.terms_notebook,(int)(this.children.length()+1),session_command,session_path,(terminal)=>{
				//close tab if autorestart=false
				if(this.children.length()>1)//don't close last tab
					this.close_tab(this.hvbox.children_index(terminal.tbutton));
				else
					terminal.start_command();
			});
		}else{
			vt = new VTTerminal(this.conf,this.terms_notebook,(int)(this.children.length()+1),session_command,session_path,on_exit );
		}

		vt.configure(this.conf);

		vt.vte_term.window_title_changed.connect( () => {
			this.title_changed((Vte.Terminal)vt.vte_term);
        } );
		children.append(vt);

		vt.tbutton.button_press_event.connect(tab_button_press_event);
		this.hvbox.add(vt.tbutton);


		this.activate_tab(vt.tbutton) ;//this.active_tab = this.hvbox.children_index(tbutton);

		this.search_update();
		return vt;
	}

	public void close_tab (int tab_position){
		unowned VTToggleButton tab_button=(VTToggleButton)this.hvbox.children_nth(tab_position);
		if(tab_button==null) return;
		this.hvbox.remove(tab_button);
		if(tab_button==this.active_tab)
			this.active_tab=null;
		//unowned
		AYTab vtt = ((AYTab)tab_button.object);

		this.children.remove(vtt);

//~ 		try {
//~ 			//if vte was in swap it may took long time, so run it in separate thread
//~ 			//GLib.Thread<void*> thread_a =
//~ 			//GLib.Thread<weak void*>thread_a =
//~ 			GLib.Thread.create<void*>(()=>{debug ("close_tab close in thread\n"); vtt.destroy(); return null;},false);//vtt.destroy() also destroys tab_button
//~ 		} catch (Error e) {
//~ 			debug ("close_tab thread %s\n", e.message);
			if(vtt is VTTerminal)
				((VTTerminal)vtt).destroy();
			else
			if(vtt is AYSettings){
				((AYSettings)vtt).destroy();
				this.aysettings_shown=false;
			}else
				vtt.destroy();
//~ 		}


		if(this.children.length()>0){
			if (tab_position>(this.children.length()-1))
				tab_position=(int)this.children.length()-1;

			unowned VTToggleButton new_active_tbutton = (VTToggleButton)this.hvbox.children_nth(tab_position);
			this.activate_tab(new_active_tbutton);
			this.update_tabs_title();
			this.search_update();
		}else
			this.add_tab();
	}

	public bool tab_button_press_event(Widget widget,Gdk.EventButton event) {
		if(event.type==Gdk.EventType.BUTTON_PRESS){
			if(event.button== 1){
				VTToggleButton tbutton = (VTToggleButton) widget;
				if ( this.active_tab != tbutton)
					activate_tab(tbutton);

			}
		}
		return false; //true == ignore event
	}//tab_button_press_event

	public void activate_tab (VTToggleButton tab_button){
		if (tab_button != null )
		if(this.active_tab==null || this.active_tab!=tab_button){
			foreach (AYTab vt in this.children) {
				if (vt.tbutton == tab_button){
					
					this.terms_notebook.set_current_page(this.terms_notebook.page_num(vt.hbox));

					if (this.active_tab!=null){
						this.active_tab.really_toggling=false;
						this.active_tab.set_active(this.active_tab.really_toggling);
					}
					this.active_tab = tab_button;
					this.active_tab.really_toggling=true;
					this.active_tab.set_active(this.active_tab.really_toggling);
					vt.tbutton.set_title((this.children.index(vt)+1),null);
					if(vt is VTTerminal){
						((VTTerminal)vt).vte_term.grab_focus();
						((VTTerminal)vt).vte_term.show () ;
						//this.set_default(vt.vte_term);
					}
					this.search_update();
					break;
					}
			}
		}else{
			if(this.active_tab.object is VTTerminal){
			((VTTerminal)this.active_tab.object).vte_term.grab_focus();
			((VTTerminal)this.active_tab.object).vte_term.show () ;
			}
			this.search_update();
		}
	}

	public void move_tab(Widget widget, uint new_index){
		VTToggleButton tab_button = (VTToggleButton) widget;
		foreach (var vt in this.children) {
			if (vt.tbutton == tab_button){
				this.children.remove(vt);
				this.children.insert( vt ,(int) new_index);
				this.activate_tab(tab_button);
				break;
			}
		}
		this.update_tabs_title();
		this.search_update();
	}

	public void update_tabs_title(){
		foreach (var vt in this.children) {
			//reindex all tabs
			vt.tbutton.set_title((int)(this.children.index(vt)+1),null);
		}
	}

	public void tab_next () {
		unowned List<unowned AYTab> item_it = null;
		unowned AYTab vt = null;
		for (item_it = this.children; item_it != null; item_it = item_it.next) {
			vt = item_it.data;
			if (vt.tbutton == this.active_tab){
				if (item_it.next!=null){
					vt = item_it.next.data;
					debug("tab_next %s",vt.tbutton.label.get_text());
					this.activate_tab(vt.tbutton) ;
					break;
				}else{
					vt = this.children.first().data;
					this.activate_tab(vt.tbutton) ;
					break;
				}
			}
		}
	}

	public void tab_prev () {
		unowned List<unowned AYTab> item_it=null;
		unowned AYTab vt=null;
		for (item_it = this.children; item_it != null; item_it = item_it.next) {
			vt = item_it.data;
			if (vt.tbutton == this.active_tab){
				if (item_it.prev!=null){
					vt = item_it.prev.data;
					this.activate_tab(vt.tbutton) ;
					break;
				}else{
					vt = this.children.last().data;
					this.activate_tab(vt.tbutton) ;
					break;
				}
			}
		}
	}

	public void title_changed(Vte.Terminal term){
		string? s = term.window_title;
		//title_changed in altyo_window
		//becouse of this.children.index
		foreach (var vt in this.children) {
			if (vt is VTTerminal && ((VTTerminal)vt).vte_term == term){
				var tab_index =  this.children.index(vt)+1;
				vt.tbutton.set_title(tab_index, s );
				if(this.tab_sort_order==TAB_SORT_ORDER.HOSTNAME)
					this.tab_sort(((VTTerminal)vt));
				break;
			}
		}

	}


	public void tab_sort (VTTerminal vt_new_title) {
		if(vt_new_title.tbutton.host_name==null ||
		   vt_new_title.tbutton.do_not_sort) return;//do not sort if hostname empty

		this.children.sort_with_data( (vt_a, vt_next_b)=>{
			VTTerminal vt = vt_a as VTTerminal, vt_next = vt_next_b as VTTerminal;
//~			//unowned VTTerminal vt = (VTTerminal)a;
//~			//unowned VTTerminal vt_next = (VTTerminal)b;
			debug("compare: %s == %s",vt.tbutton.host_name,vt_next.tbutton.host_name);
			if(vt.tbutton.host_name!=null && vt_next.tbutton.host_name!=null ){
				int res=vt.tbutton.host_name.collate(vt_next.tbutton.host_name);
				debug("compare: %d> %d == %d",res,this.children.index(vt),this.children.index(vt_next));
				if(res>0 && !vt.tbutton.do_not_sort){
					this.hvbox.place_before(vt.tbutton,vt_next.tbutton);
					return 1;
				}else if(res<0 /*&& !vt.tbutton.do_not_sort*/){
					return -1;
				}else
					return 0;
				//return vt.tbutton.host_name.collate(vt_next.tbutton.host_name);
			}else
				return 0;
		});
		this.update_tabs_title();
//~
//~		unowned List<unowned VTTerminal> item_it=null;
//~		unowned List<unowned VTTerminal> same_hostname_last=null;
//~		unowned VTTerminal vt=null;
//~		//echo -en "\033]0;denis@asd:~\007"
//~		bool modify=true;
//~		for (item_it = this.children; item_it != null ; item_it = item_it.next) {
//~				vt = item_it.data;
//~				debug("compare: %s == %s",vt.tbutton.host_name,vt_new_title.tbutton.host_name);
//~				if(vt.tbutton.host_name!=null && !vt.tbutton.do_not_sort){
//~					int res=vt.tbutton.host_name.collate(vt_new_title.tbutton.host_name);
//~					if(res==0){
//~						if(vt==vt_new_title) {modify=false; break;}
//~						else{
//~							same_hostname_last=item_it;
//~						}
//~					}else
//~					if(same_hostname_last!=null) break;
//~				}
//~		}
//~		if(modify){
//~				if(same_hostname_last!=null){
//~					int new_pos = this.children.position(same_hostname_last);
//~					if(new_pos<this.children.index(vt_new_title)) new_pos++;
//~					debug("modify: new_pos=%d",new_pos);
//~					this.children.remove(vt_new_title);
//~					this.children.insert(vt_new_title,new_pos);
//~					this.hvbox.place_on_index(vt_new_title.tbutton,new_pos);
//~					this.update_tabs_title();
//~				}
//~		}
	}//tab_sort

	public void ShowQuitDialog(){
			var dialog = new MessageDialog (null, (DialogFlags.DESTROY_WITH_PARENT | DialogFlags.MODAL), MessageType.QUESTION, ButtonsType.YES_NO, _("Really quit?"));
			var checkbox = new CheckButton.with_label(_("Save session"));
			checkbox.active=this.save_session;
			var dialog_box = ((Gtk.ButtonBox)dialog.get_action_area ());
			dialog_box.pack_start(checkbox,false,false,0);
			//dialog_box.reorder_child(checkbox,0);
			checkbox.show();
			dialog.response.connect ((response_id) => {
				if(response_id == Gtk.ResponseType.YES){
					this.save_session=checkbox.active;
					dialog.destroy ();
					this.main_window.allow_close=true;
					this.main_window.destroy();
				}else{
					this.main_window.allow_close=false;
					this.main_window.window_set_active();
					dialog.destroy ();
				}
			});

			dialog.close.connect ((response_id) => {
				this.main_window.window_set_active();
				dialog.destroy ();
			});
			dialog.focus_out_event.connect (() => {
				return true; //same bug as discribed in this.focus_out_event
				});
			dialog.set_transient_for(this.main_window);
			dialog.show ();
			dialog.grab_focus();
			this.main_window.hotkey.send_net_active_window(dialog.get_window ());
			dialog.run();
	}

	

	public void ShowHelp(){
			var dialog = new AboutDialog();
			dialog.license_type = Gtk.License.GPL_3_0;
			dialog.authors={"Konstantinov Denis linvinus@gmail.com"};
			dialog.website ="https://github.com/linvinus/AltYo";
			dialog.version ="0.2";
			dialog.translator_credits="Translation in English by willemw12@gmail.com";

			AccelMap am=Gtk.AccelMap.get();

			var p = new point_a(this.action_group);


			am.foreach(p,(pvoid,accel_path,accel_key,accel_mods,ref changed)=>{
				unowned point_a pp=(point_a*) pvoid;
				string[] regs;
				regs=GLib.Regex.split_simple("^.*/(.*)$",accel_path,RegexCompileFlags.CASELESS,0);
				string name;
				if(regs!=null && regs[1]!=null && pp.ag.get_action(regs[1])!=null){
					name="%30s \t %15s\n".printf (pp.ag.get_action(regs[1]).name, Gtk.accelerator_get_label(accel_key,accel_mods));
					pp.sb.append(name);
				}
				});

				TextTag		 tag_command,tag_key;
				TextIter iter;
				var sw=new ScrolledWindow(null,null);
				sw.border_width=6;
				sw.set_policy(Gtk.PolicyType.AUTOMATIC,Gtk.PolicyType.AUTOMATIC);


				var tvbuf = new TextBuffer( new TextTagTable() );

				tag_command = new TextTag ("command-name");
				tag_command.justification_set=true;
				tag_command.justification=Gtk.Justification.LEFT;
                tag_command.set ("weight", Pango.Weight.NORMAL, "family", "Monospace");
                tvbuf.tag_table.add (tag_command);

				tag_key = new TextTag ("key");
				tag_key.justification_set=true;
				tag_key.justification=Gtk.Justification.RIGHT;
                tag_key.set ("weight", Pango.Weight.BOLD, "family", "Monospace");
                tvbuf.tag_table.add (tag_key);


				var tv=new TextView.with_buffer( tvbuf);
				tv.editable=false;
				tv.cursor_visible=false;
				sw.add(tv);

				string[] lines = p.sb.str.split ("\n");

				foreach (string line in lines) {
					if(line==null || line=="")continue;
					string[] tarr=line.split ("\t");
					tvbuf.get_end_iter(out iter);
					tvbuf.insert_with_tags(iter,tarr[0]+":",-1,tag_command);

					tvbuf.get_end_iter(out iter);
					tvbuf.insert_with_tags(iter,tarr[1]+"\n",-1,tag_key);

				}

 			var dialog_box = ((Gtk.Box)dialog.get_content_area ());
 			dialog_box.pack_end(sw,false,false,0);
			dialog_box.reorder_child(sw,0);
			sw.set_size_request(500,200);
			dialog.response.connect ((response_id) => {
					this.main_window.window_set_active();
					dialog.destroy ();
			});

			dialog.close.connect ((response_id) => {
				this.main_window.window_set_active();
				dialog.destroy ();
			});
			dialog.focus_out_event.connect (() => {
				return true; //same bug as discribed in this.focus_out_event
				});
			dialog.set_transient_for(this.main_window);
			dialog.show_all();
			dialog.grab_focus();
			this.main_window.hotkey.send_net_active_window(dialog.get_window ());
			dialog.run();
	}

	private bool check_for_existing_action(string name,string default_accel){
		unowned Gtk.Action action = this.action_group.get_action(name);
		unowned uint accelerator_key;
		unowned Gdk.ModifierType accelerator_mods;
		unowned AccelKey* ak;

		if(action!=null){
			Gtk.accelerator_parse(conf.get_accel_string(name,default_accel),out accelerator_key,out accelerator_mods);
			ak=this.accel_group.find((key, closure) =>{	return (closure==action.get_accel_closure()); });
			//if current accel don't equal to parsed, then try to update
			if(ak->accel_key!=accelerator_key || ak->accel_mods!=accelerator_mods){
				//debug("accel error: %s key:%d mod:%d",action.get_accel_path(),(int)accelerator_key,(int)accelerator_mods);
				//update accelerator for action if parsed corrected
				if(accelerator_key!=0 && accelerator_mods!=0){
					//debug("update accel: %",action.get_accel_path());
					AccelMap am=Gtk.AccelMap.get();
					am.change_entry(action.get_accel_path(),accelerator_key,accelerator_mods,false);
				}
			}
			//just update config to be enshure that settings are same as we think
			var parsed_name=Gtk.accelerator_name (ak->accel_key, ak->accel_mods);
			conf.set_accel_string(name,parsed_name);
			return true;
		}
		return false;
	}

	private void add_window_accel(string name,string? label, string? tooltip, string? stock_id,string default_accel, MyCallBack cb){
		if(!check_for_existing_action(name,default_accel))
			this.add_window_accel_real(new Gtk.Action(name, label, tooltip, stock_id),conf.get_accel_string(name,default_accel),cb);
	}

	private void add_window_toggle_accel(string name,string? label, string? tooltip, string? stock_id,string default_accel, MyCallBack cb){
		if(!check_for_existing_action(name,default_accel))
			this.add_window_accel_real(new Gtk.ToggleAction(name, label, tooltip, stock_id),conf.get_accel_string(name,default_accel),cb);
	}

	private void add_window_accel_real(Gtk.Action action, string accel, MyCallBack cb){

		//we can't connect cb dirrectly to action.activate
		//so, using lambda again =(
		action.activate.connect(()=>{cb(action);});
		//add in to action_group to make a single repository
		this.action_group.add_action_with_accel (action,accel);
		action.set_accel_group (this.accel_group);//use main window accel group
		action.connect_accelerator ();
		//inc refcount otherwise action will be freed at the end of this function
		//action.ref();
	}

	public void setup_keyboard_accelerators() {


		if(this.accel_group==null){
			this.accel_group = new Gtk.AccelGroup();
			this.main_window.add_accel_group (accel_group);
		}

		if(this.action_group==null)
			this.action_group = new Gtk.ActionGroup("AltYo");


		/* Add New Tab on <Ctrl><Shift>t */
		this.add_window_accel("terminal_add_tab", _("New tab"), _("Open new tab"), Gtk.Stock.NEW,"<Control><Shift>T",()=>{
			this.add_tab();
		});
		this.add_window_accel("terminal_new_tab_in_current_directory", _("New tab in current directory"), _("Open new tab in current directory"), Gtk.Stock.NEW,"",()=>{
			debug("terminal_new_tab_in_current_directory");
			if(this.active_tab!=null){
				VTTerminal vt =((VTTerminal)this.active_tab.object);
				var tmp=vt.find_tty_pgrp(vt.pid,true);
				debug("path: %s",tmp);
				this.add_tab(null,tmp);
			}
		});

        /* Close Current Tab on <Ctrl><Shift>w */
		this.add_window_accel("terminal_close_tab", _("Close tab"), _("Close current tab"), Gtk.Stock.CLOSE,"<Control><Shift>W",()=> {
            this.close_tab(this.hvbox.children_index(this.active_tab));
        });

        /* Go to Next Tab on <Ctrl>Page_Down */
		this.add_window_accel("terminal_tab_next", _("Next tab"), _("Switch to next tab"), Gtk.Stock.GO_FORWARD,"<Control>Page_Down",()=> {
            this.tab_next();
        });

        /* Go to Prev Tab on <Ctrl>Page_Up */
		this.add_window_accel("terminal_tab_prev", _("Previous tab"), _("Switch to previous tab"), Gtk.Stock.GO_BACK,"<Control>Page_Up",()=> {
            this.tab_prev();
        });

		/* Change page 1..9 0 */
        for(var i=1;i<11;i++){
			this.add_window_accel("terminal_switch_tab%d".printf(i), _("Switch to tab %d").printf(i), _("Switch to tab %d").printf(i), null,"<Alt>%d".printf((i==10?0:i)),(a)=> {
					//"a" - is action, get index from action name,
					//because "i" is unavailable in action callback
					var s=a.name.replace("terminal_switch_tab","");
					var j=int.parse(s);
					var now = new DateTime.now_local();

					if(this.double_hotkey==j && this.double_hotkey_last_time!=null && now.difference(this.double_hotkey_last_time)<this.double_hotkey_milliseconds){
						this.double_hotkey=j;
						j+=10;
					}else
						this.double_hotkey=j;

					this.double_hotkey_last_time=now;

					unowned AYTab vt = children.nth_data(j-1);
					if(vt != null)
						this.activate_tab(vt.tbutton);
			});
		}

		///* Copy on <Ctrl><Shift>с */

		this.add_window_accel("terminal_copy_text",_("Copy"), _("Copy selected text"), Gtk.Stock.COPY,"<Control><Shift>C",()=> {
            this.ccopy();
        });

		/* Paste on <Ctrl><Shift>v */
		this.add_window_accel("terminal_paste_text", _("Paste"), _("Paste from primary clipboard"), Gtk.Stock.PASTE,"<Control><Shift>V",()=> {
            this.cpaste();
        });

		/* Find on <Ctrl><Shift>f */
		this.add_window_accel("terminal_search_dialog", _("Search"), _("Search"), Gtk.Stock.FIND,"<Control><Shift>F",()=> {
            this.search_show();
        });

		/* QuickLIst <Ctrl><Shift>d */
		#if HAVE_QLIST
		this.add_window_accel("altyo_toogle_quick_list", _("Show/Hide Quick list"), _("Show/Hide Quick list"), Gtk.Stock.QUIT,"<Control><Shift>D",()=> {
			if(this.tasks_notebook.get_current_page() == TASKS.TERMINALS)
				this.tasks_notebook.set_current_page(TASKS.QLIST);
			else
				this.tasks_notebook.set_current_page(TASKS.TERMINALS);
        });
        #endif

		this.add_window_toggle_accel("follow_the_mouse", _("Follow mouse cursor"), _("Follow mouse cursor"), Gtk.Stock.EDIT,"",()=> {
				this.main_window.mouse_follow = !this.main_window.mouse_follow;
        });
		this.add_window_accel("open_settings", _("Settings..."), _("Settings"), Gtk.Stock.EDIT,"",()=> {
				this.conf.save(true);//force save before edit
				/*
				VTTerminal vt;
				string editor = conf.get_string("text_editor_command","");

				if(editor=="" ||editor==null)
					editor=GLib.Environment.get_variable("EDITOR");

				string[] editor_names={"editor","nano","vi","emacs"};
				string[] paths={"/usr/bin/","/bin/","/usr/local/bin/"};
				bool done=false;
				if(editor==""||editor==null)
				foreach(string editor_name in editor_names){
					foreach(string path in paths){
						if(GLib.FileUtils.test(path+editor_name,GLib.FileTest.EXISTS|GLib.FileTest.IS_EXECUTABLE)){
						editor=path+editor_name;
						done=true;
						break;
						}
					}
					if(done) break;
				}
				debug("Found editor: %s",editor);
				vt = this.add_tab(editor+" "+this.conf.conf_file,null,(vt1)=>{
					debug("OnChildExited");
					this.conf.load_config();
					this.close_tab(this.hvbox.children_index(vt1.tbutton));
					});
				vt.auto_restart=false;
				var tab_index =  this.children.index(vt)+1;
				vt.tbutton.set_title(tab_index, _("AltYo Settings") );
				*/
				if(!this.aysettings_shown){
					this.aysettings=new AYSettings(this.conf,this.terms_notebook,(int)(this.children.length()+1),this);
					this.children.append(this.aysettings);
					this.aysettings.tbutton.button_press_event.connect(tab_button_press_event);
					this.hvbox.add(this.aysettings.tbutton);
					this.activate_tab(this.aysettings.tbutton) ;//this.active_tab = this.hvbox.children_index(tbutton);
					this.aysettings_shown=true;
				}else{
					if(this.active_tab!=this.aysettings.tbutton){
						this.activate_tab(this.aysettings.tbutton);
					}else{//close
						this.close_tab(this.hvbox.children_index(this.aysettings.tbutton));
						this.aysettings_shown=false;
					}
				}
        });



		/* Quit on <Ctrl><Shift>q */
		this.add_window_accel("altyo_exit", _("Quit"), _("Quit"), Gtk.Stock.QUIT,"<Control><Shift>Q",()=> {
			this.ShowQuitDialog();
        });

   		/* Show/hide main window on <Alt>grave
   		 * add main_hotkey just to be able show it in popup menu*/
		this.add_window_accel("main_hotkey", _("Show/Hide"), _("Show/Hide"), Gtk.Stock.GO_UP,"<Alt>grave",()=>{
			this.main_window.toogle_widnow();
		});

		/* Add New Tab on <Ctrl><Shift>t */
		this.add_window_accel("altyo_help", _("About and key bindings"), _("About and key bindings"), Gtk.Stock.NEW,"F1",()=>{
			this.ShowHelp();
		});

		this.add_window_toggle_accel("disable_sort_tab", _("Disable sort tab"), _("Disable sort tab"), Gtk.Stock.EDIT,"",()=> {
			if(this.active_tab!=null){
				debug("disable_sort_tab");
				this.active_tab.do_not_sort=!this.active_tab.do_not_sort;
				//((Gtk.ToggleAction)
			}
        });

		this.add_window_toggle_accel("keep_above", _("Stay on top"), _("Stay on top"), Gtk.Stock.EDIT,"",()=> {
			this.main_window.keep_above=!this.main_window.keep_above;
			debug("action keep_above %d",(int)this.main_window.keep_above);
			if(this.main_window.keep_above){
				this.main_window.skip_taskbar_hint = true;
				this.main_window.set_keep_above(true);
			}else{
				this.main_window.skip_taskbar_hint = false;
				this.main_window.set_keep_above(false);
			}
        });

	}//setup_keyboard_accelerators




	public void hvbox_size_changed(int width, int height,bool on_size_request){
			debug ("hvbox_size_changed start");
			if(!this.main_window.maximized){
				debug ("hvbox_size_changed w=%d h=%d  task_w=%d task_h=%d term_h=%d",width,height,this.tasks_notebook.get_allocated_width(),this.tasks_notebook.get_allocated_height(),this.terminal_height) ;

				if(this.tasks_notebook.get_allocated_width() != width || this.tasks_notebook.get_allocated_height() > this.terminal_height+1){
					this.tasks_notebook.set_size_request(this.terminal_width,this.terminal_height);
					//this.tasks_notebook.queue_resize_no_redraw();
				}

				var should_be_h = this.terminal_height+height + (this.search_hbox.get_visible()?this.search_hbox.get_allocated_height():0);
				if(this.main_window.get_allocated_height()>should_be_h+2 /*&& !this.main_window.maximized*/){
					//this.main_window.configure_position();//this needed to update position after unmaximize
					this.main_window.set_default_size(this.terminal_width,should_be_h);
					this.main_window.resize (this.terminal_width,should_be_h);
					this.main_window.move (this.main_window.orig_x,this.main_window.orig_y);
					this.main_window.queue_resize_no_redraw();
					//GLib.Timeout.add(10,()=>{debug("Update events");this.update_events(); return false;});
					debug ("hvbox_size_changed terminal_width=%d should_be_h=%d",terminal_width,should_be_h) ;
				}
			}else{
				var was_h=this.main_window.get_allocated_height();
				var was_w=this.main_window.get_allocated_width();
				var was_wn=this.tasks_notebook.get_allocated_width();
				this.tasks_notebook.set_size_request(was_wn,-1);

				this.main_window.set_default_size(was_w,was_h);
				this.main_window.resize (was_w,was_h);							
				this.main_window.queue_resize_no_redraw();
				
			}

//example (gdk_window_get_state (gtk_widget_get_window (widget)) & (GDK_WINDOW_STATE_MAXIMIZED | GDK_WINDOW_STATE_FULLSCREEN)) != 0)
	}

	public void ccopy() {
				unowned AYTab vtt = ((AYTab)this.active_tab.object);
				if(vtt is VTTerminal)
					((VTTerminal)vtt).vte_term.copy_clipboard ();
	}

	public void cpaste() {
				unowned AYTab vtt = ((AYTab)this.active_tab.object);
				if(vtt is VTTerminal)
					((VTTerminal)vtt).vte_term.paste_clipboard ();
	}

	/*public override bool focus_out_event (Gdk.EventFocus event){
		//on ubuntu 11.10,libvte9 1:0.28.2-0ubuntu2
		//prevent vost focus, for some rason we recieve focus_out_event
		//after window show, but still have input focus
		//may be in the future we will have more luck, try to comment
		//this callback
		return true;
	}*/
	public void search_update_pattern(VTTerminal vtt){
					string? s_pattern = null;
					GLib.RegexCompileFlags cflags = 0;
					if( vtt.vte_term.search_get_gregex() != null ){
						var rgx=vtt.vte_term.search_get_gregex();
						s_pattern = rgx.get_pattern();
						cflags=rgx.get_compile_flags();
					}
					string? new_pattern = this.search_text_combo.get_active_text();
					debug(" new_pattern '%s' != '%s'", new_pattern,s_pattern);
					bool needs_udatate = false;
					//if((cflags & GLib.RegexCompileFlags.CASELESS)!=(int)(!vtt.match_case)) {
						cflags = GLib.RegexCompileFlags.OPTIMIZE;
						if(!vtt.match_case)
							cflags |= GLib.RegexCompileFlags.CASELESS;
						//needs_udatate=true;
					//}



					if( (s_pattern == null && new_pattern != null && new_pattern != "") ||
						(s_pattern != null && new_pattern != null && s_pattern != new_pattern) ){
							search_add_string(new_pattern);
							needs_udatate=true;
						}
					if(needs_udatate){
						var reg_exp = new GLib.Regex(new_pattern,cflags);
						vtt.vte_term.search_set_gregex(reg_exp);
					}
	}

	public void create_search_box(){
		this.search_text_combo = new ComboBoxText.with_entry ();
		((Entry)this.search_text_combo.get_child()).key_press_event.connect((event)=>{
			unowned AYTab ayt = ((AYTab)this.active_tab.object);
			if(!(ayt is VTTerminal)) return false;
			unowned VTTerminal vtt = ((VTTerminal) ayt);
			var keyname = Gdk.keyval_name(event.keyval);
			if( keyname == "Return"){
					this.search_update_pattern(vtt);
					vtt.vte_term.search_find_previous();
					return true;
				}else if( keyname == "Up" && (event.state & Gdk.ModifierType.CONTROL_MASK ) == Gdk.ModifierType.CONTROL_MASK ){
					vtt.vte_term.search_find_previous();
					return true;
				}else if( keyname == "Down" && (event.state & Gdk.ModifierType.CONTROL_MASK ) == Gdk.ModifierType.CONTROL_MASK ){
					vtt.vte_term.search_find_next();
					return true;
				}else if( keyname == "Escape"){
					this.search_hide();
					return true;
				}
			return false;
			});
		this.search_text_combo.show();
		this.search_hbox.pack_start(search_text_combo,false,false,0);

		string[]? search_s_conf = this.conf.get_string_list("search_history",null);

		if(search_s_conf!=null && search_s_conf.length<=this.search_history_length)
			foreach(var s in search_s_conf){
				this.search_text_combo.prepend_text(s);
			}


		this.search_wrap_around = new CheckButton.with_label(_("Wrap search"));
		this.search_wrap_around.clicked.connect(()=>{
			unowned AYTab vtt = ((AYTab)this.active_tab.object);
			if(!(vtt is VTTerminal)) return;
			((VTTerminal)vtt).vte_term.search_set_wrap_around(this.search_wrap_around.active);
			this.search_text_combo.grab_focus();
			});
		this.search_wrap_around.show();
		this.search_hbox.pack_start(this.search_wrap_around,false,false,0);

		this.search_match_case = new CheckButton.with_label(_("Match case-sensitive"));
		this.search_match_case.clicked.connect(()=>{
			unowned AYTab vtt = ((AYTab)this.active_tab.object);
			if(!(vtt is VTTerminal)) return;
			((VTTerminal)vtt).match_case=this.search_match_case.active;
			this.search_text_combo.grab_focus();
			});
		this.search_match_case.show();
		this.search_hbox.pack_start(this.search_match_case,false,false,0);


		var next_button = new Button();
		Image img = new Image.from_stock ("gtk-go-up",Gtk.IconSize.SMALL_TOOLBAR);
		next_button.add(img);
		next_button.clicked.connect(()=>{
			unowned AYTab ayt = ((AYTab)this.active_tab.object);
			if(!(ayt is VTTerminal)) return;
			unowned VTTerminal vtt = (VTTerminal)ayt;
			this.search_update_pattern(vtt);
			vtt.vte_term.search_find_previous();
			});
		next_button.set_focus_on_click(false);
		next_button.show();
		this.search_hbox.pack_start(next_button,false,false,0);

		var prev_button = new Button();
		img = new Image.from_stock ("gtk-go-down",Gtk.IconSize.SMALL_TOOLBAR);
		prev_button.add(img);
		prev_button.clicked.connect(()=>{
			unowned AYTab ayt = ((AYTab)this.active_tab.object);
			if(!(ayt is VTTerminal)) return;
			unowned VTTerminal vtt = (VTTerminal)ayt;
			this.search_update_pattern(vtt);
			vtt.vte_term.search_find_next();
			});
		prev_button.set_focus_on_click(false);
		prev_button.show();
		this.search_hbox.pack_start(prev_button,false,false,0);

		var hide_button = new Button();
		img = new Image.from_stock ("gtk-close",Gtk.IconSize.SMALL_TOOLBAR);
		hide_button.add(img);
		hide_button.clicked.connect(()=>{
			this.search_hide();
			});
		hide_button.set_focus_on_click(false);
		hide_button.show();
		this.search_hbox.pack_end(hide_button,false,false,0);


	}//create_search_box

	public void search_show(){
		unowned AYTab vtt = ((AYTab)this.active_tab.object);
		if(!(vtt is VTTerminal)) return;
		if(!((Entry)this.search_text_combo.get_child()).has_focus){
			
			if(this.main_window.maximized){
				var was_h=this.main_window.get_allocated_height();
				var was_w=this.main_window.get_allocated_width();
				var was_wn=this.tasks_notebook.get_allocated_width();
				this.tasks_notebook.set_size_request(was_wn,-1);
				this.search_hbox.show();

				this.main_window.set_default_size(was_w,was_h);
				this.main_window.resize (was_w,was_h);							
				this.main_window.queue_resize_no_redraw();
			}else
				this.search_hbox.show();
					
			var term = ((VTTerminal)this.active_tab.object).vte_term;
			if( term.get_has_selection()){
				term.copy_clipboard();
				var display = this.main_window.get_display ();
				var clipboard = Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
				// Get text from clipboard
				string text = clipboard.wait_for_text ();
				if(text != null && text != "")
					((Entry)this.search_text_combo.get_child()).set_text(text);
			}
			this.search_update();
			this.search_text_combo.grab_focus();
		}else{
			this.search_hide();
		}
	}

	public void search_update(){
		if(this.search_hbox.visible){
			unowned AYTab vtt = ((AYTab)this.active_tab.object);
			if(!(vtt is VTTerminal)) {
				this.search_hide();
				return;
			}
			
			this.search_wrap_around.active=((VTTerminal)vtt).vte_term.search_get_wrap_around();
			this.search_match_case.active=((VTTerminal)vtt).match_case;
		}

//~ 		Gdk.RGBA c = Gdk.RGBA();
//~         c.parse("#AAAAAA");//black todo: make same color as vte
//~         c.alpha = 1.0;//transparency
//~         this.search_wrap_around.get_child ().override_color(StateFlags.NORMAL, c);
//~         this.search_match_case.get_child ().override_color(StateFlags.NORMAL, c);
//~         c.parse("#000000");//black todo: make same color as vte
//~         this.search_wrap_around.override_background_color(StateFlags.PRELIGHT, c);
//~         this.search_wrap_around.override_background_color(StateFlags.ACTIVE, c);
//~         this.search_match_case.override_background_color(StateFlags.PRELIGHT, c);
//~         this.search_match_case.override_background_color(StateFlags.ACTIVE, c);
	}

	public void search_hide(){
		//prevent resizing of the terminal after closing the search
		var should_be_h = this.terminal_height+this.hvbox.get_allocated_height();
		if(this.main_window.get_allocated_height()>should_be_h+2){
			//this.configure_position();//this needed to update position after unmaximize
			this.main_vbox.set_size_request(this.terminal_width,should_be_h);
			this.main_window.set_default_size(this.terminal_width,should_be_h);
			this.main_window.resize (this.terminal_width,should_be_h);
			this.main_window.queue_resize_no_redraw();
			
			//GLib.Timeout.add(10,()=>{debug("Update events");this.update_events(); return false;});
			debug ("search_hide terminal_width=%d should_be_h=%d",terminal_width,should_be_h) ;
		}				
		this.search_hbox.hide();

		unowned AYTab vtt = ((AYTab)this.active_tab.object);
		if(vtt is VTTerminal) {
			((VTTerminal)vtt).vte_term.search_set_gregex(null);
			((VTTerminal)vtt).vte_term.grab_focus();
		}
	}

	public bool search_add_string(string text){
		debug("search_add_string");
		if(text != null && text != ""){
			unowned TreeIter iter;
			var index = 0;
			//try to find in a list, and place item at start
			if(this.search_text_combo.model.get_iter_first(out iter))
				do{
					unowned string s;
					this.search_text_combo.model.get(iter,0,out s);
					if(s == text){
						this.search_text_combo.remove(index);
						this.search_text_combo.prepend_text(text);
						return true;
						}
					index++;
				}while(this.search_text_combo.model.iter_next(ref iter));

			var count = this.search_text_combo.model.iter_n_children(null);
			if(count>this.search_history_length-1)//max count in a history
				this.search_text_combo.remove(count-1);
			this.search_text_combo.prepend_text(text);
			return true;
			}
		return false;
	}



	public void save_configuration(){
		string[] search_s = new string [this.search_history_length];
		unowned TreeIter iter;
		var count = this.search_text_combo.model.iter_n_children(null);
		//reverse index
		int index = count-1;
		if(this.search_text_combo.model.get_iter_first(out iter))
			do{
				unowned string s;
				this.search_text_combo.model.get(iter,0,out s);
				search_s[index]=s;
				index--;
			}while(this.search_text_combo.model.iter_next(ref iter) && index>=0);


		this.conf.set_string_list("search_history",search_s);

			string[] terminal_session = {};
			var grx_exclude = new GLib.Regex(this.conf.get_string("terminal_session_exclude_regex","/?zsh\\ ?|/?mc\\ ?|/?bash\\ ?"));
			foreach (var vt in this.children) {
				if(vt is VTTerminal){
					var tmp=((VTTerminal)vt).find_tty_pgrp(((VTTerminal)vt).pid);
					if(tmp!="" && !grx_exclude.match_all(tmp,0,null) && this.save_session)
						terminal_session+=tmp;
					((VTTerminal)vt).destroy();
				}
			}
			//g_list_free(this.children);
			this.conf.set_string_list("terminal_session",terminal_session);
	}//save_configuration

	public void on_switch_task (Widget page, uint page_num) {
		if(page_num==TASKS.TERMINALS){
			//while loading,on_switch_task perhaps before this.action_group is configured
			if(this.action_group!=null) //ignore if not configured
				this.action_group.sensitive=true;
			//this.overlay_notebook.hide();
			unowned AYTab vtt = ((AYTab)this.active_tab.object);
			if((vtt is VTTerminal)) 
				((VTTerminal) vtt).vte_term.grab_focus();
		}else if(page_num==TASKS.QLIST){
			if(this.action_group!=null) //ignore if not configured
				this.action_group.sensitive=false;
			//this.overlay_notebook.show();

		}
		page.set_size_request(-1,this.terminal_height);
	}

	public void on_maximize(bool new_maximize){
		if(new_maximize && this.tasks_notebook.halign!=Gtk.Align.FILL){
			this.tasks_notebook.halign=Gtk.Align.FILL;
			this.tasks_notebook.valign=Gtk.Align.FILL;
			this.tasks_notebook.expand=true;
			this.tasks_notebook.queue_resize_no_redraw();
			debug("maximize==FILL");
		}else if(!new_maximize && this.tasks_notebook.halign!=Gtk.Align.START){
			this.tasks_notebook.halign=Gtk.Align.START;
			this.tasks_notebook.valign=Gtk.Align.START;
			this.tasks_notebook.expand=false;
			this.tasks_notebook.queue_resize_no_redraw();
			debug("maximize==START");
		}
		
	}

}//class AYObject

