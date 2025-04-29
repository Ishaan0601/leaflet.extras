"use strict";
!function(){
  function t(i){
    return this instanceof t
      ? ( this._canvas = i = "string" == typeof i
            ? document.getElementById(i)
            : i,
          this._ctx = i.getContext("2d"),
          this._width = i.width,
          this._height = i.height,
          this._max = 1,
          void this.clear() )
      : new t(i);
  }

  t.prototype = {
    defaultRadius:25,
    defaultGradient:{.4:"blue",.6:"cyan",.7:"lime",.8:"yellow",1:"red"},

    data:function(t,i){ return this._data = t, this; },
    max:function(t){ return this._max = t, this; },
    add:function(t){ return this._data.push(t), this; },
    clear:function(){ return this._data = [], this; },

    radius:function(t,i){
      i = i||15;
      var a = this._circle = document.createElement("canvas"),
          s = a.getContext("2d"),
          e = this._r = t + i;
      a.width = a.height = 2*e;
      s.shadowOffsetX = s.shadowOffsetY = 200;
      s.shadowBlur = i;
      s.shadowColor = "black";
      s.beginPath();
      s.arc(e-200, e-200, t, 0, 2*Math.PI, !0);
      s.closePath();
      s.fill();
      return this;
    },

    gradient:function(t){
      var i = document.createElement("canvas"),
          a = i.getContext("2d"),
          s = a.createLinearGradient(0,0,0,256);
      i.width = 1; i.height = 256;
      for(var e in t) s.addColorStop(e, t[e]);
      a.fillStyle = s;
      a.fillRect(0,0,1,256);
      this._grad = a.getImageData(0,0,1,256).data;
      return this;
    },

    draw:function(t){
      this._circle || this.radius(this.defaultRadius);
      this._grad   || this.gradient(this.defaultGradient);

      var i = this._ctx;
      i.clearRect(0,0,this._width,this._height);

      for(var a,s=0,e=this._data.length; s<e; s++){
        a = this._data[s];
        i.globalAlpha = Math.max(a[2]/this._max, t||.05);
        i.drawImage(this._circle, a[0]-this._r, a[1]-this._r);
      }

      var n = i.getImageData(0,0,this._width,this._height);
      this._colorize(n.data, this._grad);
      i.putImageData(n, 0, 0);

      return this;
    },

    _colorize:function(t,i){
      for(var a,s=3,e=t.length; s<e; s+=4){
        a = 4 * t[s];
        if(a){
          t[s-3] = i[a];
          t[s-2] = i[a+1];
          t[s-1] = i[a+2];
        }
      }
    }
  };

  window.simpleheat = t;
}();

L.HeatLayer = (L.Layer ? L.Layer : L.Class).extend({
  initialize:function(t,i){
    this._latlngs = t;
    L.setOptions(this,i);
  },

  setLatLngs:function(t){ return this._latlngs = t, this.redraw(); },
  addLatLng:function(t){ return this._latlngs.push(t), this.redraw(); },
  setOptions:function(t){
    L.setOptions(this,t);
    this._heat && this._updateOptions();
    return this.redraw();
  },

  redraw:function(){
    if(this._heat && !this._frame && this._map && !this._map._animating){
      this._frame = L.Util.requestAnimFrame(this._redraw, this);
    }
    return this;
  },

  onAdd:function(map){
    this._map = map;
    if(!this._canvas) { this._initCanvas(); }
    (this.options.pane ? this.getPane() : map._panes.overlayPane)
      .appendChild(this._canvas);

    map.on("moveend", this._reset, this);
    if(map.options.zoomAnimation && L.Browser.any3d){
      map.on("zoomanim", this._animateZoom, this);
    }

    // initial draw
    this._reset();

    // ——— Crosstalk integration ———
    if(window.crosstalk && this.options.crosstalkGroup && this.options.rawData){
      var fh = new crosstalk.FilterHandle(this.options.crosstalkGroup);
      fh.on("change", function(e){
        // e.value is the array of selected keys
        var pts = this.options.rawData
          .filter(function(r){ return e.value.indexOf(r.key) >= 0; })
          .map(function(r){
            var p = this._map.latLngToContainerPoint([r.lat, r.lng]);
            return [ Math.round(p.x), Math.round(p.y), r.weight ];
          }, this);

        this._heat.data(pts).draw(this.options.minOpacity);
      }.bind(this));
    }
  },

  onRemove:function(map){
    if(this.options.pane) this.getPane().removeChild(this._canvas);
    else                 map.getPanes().overlayPane.removeChild(this._canvas);

    map.off("moveend", this._reset, this);
    if(map.options.zoomAnimation){
      map.off("zoomanim", this._animateZoom, this);
    }
  },

  addTo:function(map){ return map.addLayer(this), this; },

  _initCanvas:function(){
    var c = this._canvas = L.DomUtil.create("canvas",
                  "leaflet-heatmap-layer leaflet-layer"),
        origin = L.DomUtil.testProp(
                  ["transformOrigin","WebkitTransformOrigin","msTransformOrigin"]);
    c.style[origin] = "50% 50%";

    var size = this._map.getSize();
    c.width = size.x; c.height = size.y;

    var animated = this._map.options.zoomAnimation && L.Browser.any3d;
    L.DomUtil.addClass(c, "leaflet-zoom-" + (animated ? "animated" : "hide"));

    this._heat = simpleheat(c);
    this._updateOptions();
  },

  _updateOptions:function(){
    this._heat.radius(
      this.options.radius || this._heat.defaultRadius,
      this.options.blur
    );
    if(this.options.gradient) this._heat.gradient(this.options.gradient);
    if(this.options.max)      this._heat.max(this.options.max);
  },

  _reset:function(){
    var pos = this._map.containerPointToLayerPoint([0,0]);
    L.DomUtil.setPosition(this._canvas, pos);

    var size = this._map.getSize();
    if(this._heat._width !== size.x){
      this._canvas.width = this._heat._width = size.x;
    }
    if(this._heat._height !== size.y){
      this._canvas.height = this._heat._height = size.y;
    }

    this._redraw();
  },

  _redraw:function(){
    if(!this._map) return;

    // build clustered pixel list 'd'
    var data = [], r = this._heat._r,
        size = this._map.getSize(),
        bounds = new L.Bounds(L.point([-r,-r]), size.add([r,r])),
        maxWeight = this.options.max === undefined ? 1 : this.options.max,
        cellSize = this.options.cellSize === undefined ? r/2 : this.options.cellSize,
        grid = [], origin = this._map._getMapPanePos(),
        offsetX = origin.x % cellSize,
        offsetY = origin.y % cellSize,
        latlngs = this._latlngs;

    for(var i=0, len=latlngs.length; i<len; i++){
      var a = this._map.latLngToContainerPoint(latlngs[i]);
      if(!bounds.contains(a)) continue;

      var gx = Math.floor((a.x - offsetX)/cellSize)+2,
          gy = Math.floor((a.y - offsetY)/cellSize)+2,
          w  = latlngs[i].alt !== undefined
             ? latlngs[i].alt
             : +latlngs[i][2] || 1,
          cell = grid[gy] = grid[gy] || [],
          pt   = cell[gx];

      if(pt){
        pt[0] = (pt[0]*pt[2] + a.x*w)/(pt[2]+w);
        pt[1] = (pt[1]*pt[2] + a.y*w)/(pt[2]+w);
        pt[2] = pt[2] + w;
      } else {
        cell[gx] = [a.x, a.y, w];
      }
    }

    for(var y=0; y<grid.length; y++){
      if(!grid[y]) continue;
      for(var x=0; x<grid[y].length; x++){
        var pt = grid[y][x];
        if(pt){
          data.push([
            Math.round(pt[0]),
            Math.round(pt[1]),
            Math.min(pt[2], maxWeight)
          ]);
        }
      }
    }

    this._heat.data(data).draw(this.options.minOpacity);
    this._frame = null;
  },

  _animateZoom:function(e){
    var scale = this._map.getZoomScale(e.zoom),
        offset = this._map._getCenterOffset(e.center)
                   .multiplyBy(-scale)
                   .subtract(this._map._getMapPanePos());

    if(L.DomUtil.setTransform){
      L.DomUtil.setTransform(this._canvas, offset, scale);
    } else {
      this._canvas.style[L.DomUtil.TRANSFORM] =
        L.DomUtil.getTranslateString(offset) + " scale(" + scale + ")";
    }
  }
});

L.heatLayer = function(t,i){ return new L.HeatLayer(t,i); };
