(ns secd.ui.core
  (:require [reagent.core :as r]
            [reagent.dom :as rd]))

(defonce state (r/atom {:devices [] :device nil :ws nil
                        :console "" :status "disconnected"}))

(defn connect! []
  (let [ws (js/WebSocket. (str "ws://" js/location.host "/socket"))]
    (set! (.-onopen ws) #(swap! state assoc :status "connected"))
    (set! (.-onmessage ws)
          (fn [e]
            (let [m (js->clj (js/JSON.parse (.-data e)) :keywordize-keys true)]
              (case (:type m)
                "hello" (.send ws (js/JSON.stringify {:cmd "devices"}))
                "devices" (swap! state assoc :devices (:list m))
                "selected" (swap! state assoc :device (:name m))
                "console" (swap! state update :console str (:text m))
                "halted" (swap! state assoc :status (str "halted err=" (:error m)))
                nil))))
    (swap! state assoc :ws ws)))

(defn send! [msg] (some-> (:ws @state) (.send (js/JSON.stringify (clj->js msg)))))

(defn ui []
  [:div
   [:h1 "SECD Emulator"]
   [:p "status: " (:status @state) " device: " (or (:device @state) "—")]
   [:div
    [:select {:value (or (:device @state) "")
              :on-change #(send! {:cmd "select" :name (.. % -target -value)})}
     (for [d (:devices @state)]
       ^{:key (:name d)} [:option {:value (:name d)} (str (:board d) " (" (:chip d) ")")])]
    " "
    [:button {:on-click #(send! {:cmd "devices"})} "refresh"]]
   [:div
    [:input {:type "file" :id "file"}]
    [:button {:on-click (fn []
                          (let [f (.getElementById js/document "file")
                                file (and f (.-files ^js/F f))]
                            (when-let [file (and file (aget file 0))]
                              (let [rd (js/FileReader.)]
                                (setf (.-onload rd)
                                      (fn [e]
                                        (let [b (js/Uint8Array. (.. e target -result))
                                              bin (apply str (map #(String/fromCharCode %) b))]
                                          (send! {:cmd "load" :bytecode-b64 (.btoa js/window bin)}))))
                                (.readAsArrayBuffer rd file)))))
             } "load"]
    [:button {:on-click #(send! {:cmd "run"})} "run"]
    [:button {:on-click #(send! {:cmd "reset"})} "reset"]]
   [:pre {:style {:background "#000" :color "#0f0" :min-height "12em"
                  :white-space :pre-wrap}}
    (:console @state)]
   [:input {:type "text" :placeholder "stdin"
            :on-key-down (fn [e]
                           (when (= (.-key e) "Enter")
                             (let [v (str (.. e -target -value) "\n")]
                               (send! {:cmd "console-in" :text v})
                               (swap! state update :console str v)
                               (setf (.. e -target -value) ""))))}]])

(defn init []
  (connect!)
  (rd/render [ui] (js/document.getElementById "app")))

(js/setTimeout connect! 100)
